# Most code here is from uv example for Dockerfile. We use python 3.9 as the base.
#FROM ghcr.io/astral-sh/uv:python3.9-bookworm-slim
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
  apt-get install -y wget bzip2 ca-certificates curl git build-essential clang-format git wget cmake build-essential autoconf libtool pkg-config libgoogle-glog-dev clang \
  golang-go python3-dev                \
  protobuf-compiler libprotobuf-dev
# RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
#   && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
#   sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
#   tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
#
# RUN sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
# ENV NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
# RUN  apt-get update && apt-get install -y \
#   nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
#   nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
#   libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
#   libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION} && \
#
RUN rm -rf /var/lib/apt/lists/*

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Setting work directory
WORKDIR /app

RUN uv venv

# Pre-install problematic dependencies
RUN uv pip install cython numpy "setuptools>=18.0" wheel

# Copy dependency files first 
COPY pyproject.toml /app/
COPY uv.lock /app/
COPY thirdparty/ /app/thirdparty/

RUN uv pip install pybind11

# Install the project's dependencies using the lockfile and settings
RUN uv sync --no-install-project --no-dev

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
RUN uv pip install mypy-protobuf

# COPY ./dipcc/ /app/dipcc/
# COPY ./fairdiplomacy/ /app/fairdiplomacy/
# COPY ./heyhi/ /app/heyhi/
# COPY ./conf/ /app/conf/
# COPY ./Makefile /app/Makefile

# .venv/lib/python3.7/site-packages/pybind11/share/cmake/pybind11/
#RUN pybind11_DIR="/app/.venv/lib/python3.7/site-packages/pybind11/share/cmake/pybind11/"  make
ENV PATH="/app/.venv/bin/:$PATH"
RUN apt update && apt install -y python3-pybind11
RUN . /app/.venv/bin/activate
RUN uv pip install "pybind11[global]"
COPY . /app/
RUN CMAKE_PREFIX_PATH="/app/.venv/lib/python3.7/site-packages/"  make

# Reset the entrypoint, don't invoke `uv`
ENTRYPOINT []

# Expose port 8000 (FastAPI runs on this)
EXPOSE 8000

# Redis is needed to run with webdiplomacy, so put here but not used yet
ENV REDIS_PORT=""
ENV REDIS_IP="localhost:"


# potentially the command to run on a webdiplomacy game, but you need to change the URL within the codebase if you want to run your own game.
#CMD [python run.py --adhoc -c conf/c07_play_webdip/play.prototxt \
# api_key=replace_this_with_api_key \
# account_name=replace_this_with_name_of_bot \
# allow_dialogue=true \
# log_dir=/logs/ \
# only_bump_msg_reviews_for_same_power=true \
# require_message_approval=false \
# is_backup=false \
# retry_exception_attempts=10 \
# reset_bad_games=1 \
# I.agent=agents/bqre1p_parlai_20220819_cicero_2.prototxt

CMD ["python","run.py","--adhoc","--cfg","conf/c01_ag_cmp/cmp.prototxt","Iagent_one=agents/cicero.prototxt","use_shared_agent=1","power_one=TURKEY"]
