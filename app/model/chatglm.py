"""ChatGLM"""
# pylint: disable=no-member
from threading import Thread
import torch
from transformers import TextIteratorStreamer, AutoModel
from transformers.generation import LogitsProcessorList, LogitsProcessor
from .llm import BaseLLM, format_messages_glm


class InvalidScoreLogitsProcessor(LogitsProcessor):
    """Invalid Score Logits Processor"""

    def __call__(self, _: torch.LongTensor, scores: torch.FloatTensor) -> torch.FloatTensor:
        if torch.isnan(scores).any() or torch.isinf(scores).any():
            scores.zero_()
            scores[..., 5] = 5e4
        return scores


class ChatGLMStreamer(TextIteratorStreamer):
    """ChatGLM streamer"""

    def put(self, value):
        """
        Receives tokens, decodes them, and prints them to stdout as soon as they form entire words.
        """
        if self.skip_prompt and self.next_tokens_are_prompt:
            self.next_tokens_are_prompt = False
            return
        text = self.tokenizer.decode([value[0]], **self.decode_kwargs)
        self.on_finalized_text(text)


class ChatGLM(BaseLLM):
    """ChatGLM"""

    def __init__(self, model_name_or_path: str, **kwargs):
        print(model_name_or_path)
       
        if 'chatglm2-6b-int4' in model_name_or_path:
            model = AutoModel.from_pretrained(model_name_or_path, trust_remote_code=True).half().cuda()
        else:
            model = AutoModel.from_pretrained(model_name_or_path, torch_dtype=torch.float16, device_map="auto",trust_remote_code=True)
        super().__init__(model_name_or_path, model=model, **kwargs)

    def stream_chat(self, messages, **kwargs):
        """stream chat"""
        logits_processor = LogitsProcessorList()
        logits_processor.append(InvalidScoreLogitsProcessor())
        streamer = ChatGLMStreamer(self.tokenizer, skip_special_tokens=True, skip_prompt=True)
        prompt, history = format_messages_glm(messages)
        inputs = self.model.build_inputs(self.tokenizer, prompt, history)
        gen_kwargs = {**inputs,
                      "logits_processor": logits_processor,
                      "streamer": streamer,
                      **kwargs}
        thread = Thread(target=self.model.generate, kwargs=gen_kwargs)
        thread.start()
        return streamer

    def chat(self, messages, **kwargs):
        """chat"""
        logits_processor = LogitsProcessorList()
        logits_processor.append(InvalidScoreLogitsProcessor())
        prompt, history = format_messages_glm(messages)
        inputs = self.model.build_inputs(self.tokenizer, prompt, history)
        outputs = self.model.generate(**inputs, logits_processor=logits_processor, **kwargs)
        outputs = outputs.tolist()[0][len(inputs["input_ids"][0]):]
        resp = self.tokenizer.decode(outputs)
        resp = self.model.process_response(resp)
        return resp
