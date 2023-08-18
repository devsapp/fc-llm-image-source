# 模型服务

将 HuggingFace 的模型封装成 OpenAI 的接口 （参考: https://github.com/abetlen/llama-cpp-python/blob/main/llama_cpp/server/app.py）

## 请求参数

暴露了几乎所有[HuggingFace Generation Config](https://huggingface.co/docs/transformers/main/main_classes/text_generation)的参数，没有暴露的部分是因为 Pydantic 无法对参数做校验

## 如何添加新模型

请参考 model 下 Qwen 作为实现的模版，在 stream_chat 中调用模型的流式传输的接口，yield 模型的输出内容即可，在 chat 调用非流式的接口

- 如果模型本身不提供流式接口，请参考 Llama, InternLM 的实现
- 如果模型加载的 config 里没有 AutoModelForCasualLM，请参考 ChatGLM 的实现
- fp16 半精度加速，请参考 InternLM 的实现，需设置 torch_dtype=torch.float16
- 量化模型，请参考https://huggingface.co/docs/transformers/main_classes/quantization
