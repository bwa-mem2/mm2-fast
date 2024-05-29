FROM ubuntu:22.04
# PYTHON_VERSION is also set in settings.sh.

RUN apt-get update
RUN apt-get install -y build-essential git zlib1g-dev curl time
#time is required


#RUN git clone --recursive https://github.com/bwa-mem2/mm2-fast.git
WORKDIR /mm2-fast
COPY . /mm2-fast/

###minimap2 baseline
WORKDIR /mm2-fast
RUN make clean && make no_opt=1
RUN mkdir /baseline/
RUN mv minimap2* /baseline/
RUN make clean

###mm2-fast
WORKDIR /mm2-fast
RUN make clean && make
RUN mkdir -p /mm2fast/
RUN mv minimap2* /mm2fast/
RUN make clean


### RUST 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 
RUN . "$HOME/.cargo/env"
ENV PATH=/root/.cargo/bin:$PATH


## Step to install rust project dependancy
#https://github.com/learnedsystems/RMI/tree/5fdff45d0929beaccf6bc56f8f4c0d82baf10304
WORKDIR /rust/src/PROJ/
RUN cp -r /mm2-fast/ext/TAL/ext/build-rmi/learned-systems-rmi/  /rust/src/PROJ/
# /rust/src/PROJ/
WORKDIR /rust/src/PROJ/learned-systems-rmi/
RUN cargo build --release \
    &&  rm -rf /rust

## LISA mm2-fast

WORKDIR /mm2-fast
RUN make clean && make lhash=1
RUN mkdir -p /lisa/mm2-fast
RUN mv minimap2* /lisa/mm2-fast/
RUN make clean

WORKDIR /mm2-fast
RUN CXX=g++ && make clean && make lhash_index=1
RUN mkdir -p /lisa/index/mm2-fast
RUN mv minimap2* /lisa/index/mm2-fast/

RUN CXX=g++ && make clean && make lhash_index=1

WORKDIR /mm2-fast/ext/TAL
RUN CXX=g++ && make lisa_hash

COPY ./create_lisa_index.sh /lisa/
