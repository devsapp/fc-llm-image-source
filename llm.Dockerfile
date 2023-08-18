# docker build -t llm:latest . --platform linux/amd64 -f llm.Dockerfile

FROM  pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel

USER root

ENV ROOT=/llm

ENV LLM_BUILTIN=/built-in

ENV PYTHONPATH=${ROOT}:$PYTHONPATH


COPY ./app ${LLM_BUILTIN}/app
COPY ./models ${LLM_BUILTIN}/models

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=8089

LABEL MAINTAINER="hanxie"

RUN mkdir -p ${ROOT}

WORKDIR ${ROOT}

RUN apt-get update -y && apt-get install -y tzdata && apt-get install python3 python3-pip curl -y

RUN ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
  dpkg-reconfigure -f noninteractive tzdata

ENV NVIDIA_DRIVER_CAPABILITIES compute,graphics,utility

RUN apt-get update
RUN apt-get install -y nvidia-container-toolkit-base && apt-get install libgl1-mesa-glx -y
RUN apt-get install -y libglib2.0-0 libsm6 libxrender1 libxext6 libvulkan1 libvulkan-dev vulkan-tools git && apt-get clean
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py 

RUN git clone https://github.com/timdettmers/bitsandbytes.git --depth 1 -b main
RUN cd bitsandbytes && CUDA_VERSION=117 make cuda11x && python3 setup.py install

COPY ./requirements.txt ${ROOT}/requirements.txt
RUN pip3 install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn --timeout 600 && rm -rf `pip3 cache dir`
RUN CMAKE_ARGS="-DLLAMA_CUBLAS=on" FORCE_CMAKE=1 pip3 install llama-cpp-python

# RUN git clone https://github.com/Dao-AILab/flash-attention --depth 1 -b v1.0.9
# RUN MAX_JOBS=4 pip install flash-attn --no-build-isolation

EXPOSE ${PORT}
COPY ./entrypoint.sh /docker/entrypoint.sh
RUN chmod +x /docker/entrypoint.sh
ENTRYPOINT ["/docker/entrypoint.sh"]