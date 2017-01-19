FROM alpine
COPY . /app

ENV mirror "http://dl-4.alpinelinux.org/alpine"

RUN echo "${mirror}/v3.3/main" > /etc/apk/repositories
RUN echo "${mirror}/v3.3/community" >> /etc/apk/repositories

# Main dependencies
# TODO: no actual need for ffmpeg other than required by hiptext build
RUN apk add --no-cache bc xvfb ttf-dejavu openssh mosh dbus firefox ffmpeg \
  libxtst libxinerama libxkbcommon

# Installing Hiptext, video to text renderer and our own interfacer.go
# Keep this all in one RUN command so that the resulting Docker image is smaller.
RUN apk --no-cache add --virtual build-dependencies \
  build-base automake autoconf cmake libtool \
  git go freetype-dev jpeg-dev ragel ffmpeg-dev \
  libx11-dev libxt-dev libxext-dev libxtst-dev libxinerama-dev libxkbcommon-dev \

  && mkdir -p build \
  && cd build \

  # The Alpine version of xdotool is only available in edge and conflicts
  # with other packages, so we need to compile it ourselves.
  && git clone https://github.com/jordansissel/xdotool \
  && cd xdotool && make && make install && cd .. \

  # Glog also is only available in edge and so causes conflicts unless we
  # compile it ourselves.
  && git clone https://github.com/google/glog \
  && cd glog \
  && autoreconf -vfi \
  && ./configure --prefix=/usr \
  && make && make install \
  && cd .. \

  # gflags was remvoed from the Alpine repos :(
  && git clone https://github.com/gflags/gflags \
  && cd gflags && mkdir build && cd build \
  && cmake -DCMAKE_INSTALL_PREFIX=/usr .. \
  && make && make install \
  && cd ../.. \

  && git clone https://github.com/tombh/hiptext \
  && cd hiptext \
  && git checkout ffmpeg-updates-and-unicode-hack \
  && make \
  # Alpine's version of `install` doesn't support the `--mode=` format
  && install -m 0755 hiptext /usr/local/bin \
  && cd ../.. && rm -rf build \

  # Build the interfacer.go/xzoom code
  && export GOPATH=/go && export GOBIN=/app/interfacer \
  && cd /app/interfacer && go get && go build \

  && apk --no-cache del build-dependencies

# Generate host keys
RUN ssh-keygen -A

RUN sed -i 's/#Port 22/Port 7777/' /etc/ssh/sshd_config

RUN mkdir -p /app/logs

WORKDIR /app
CMD ["/usr/sbin/sshd", "-D"]
