FROM mjmckinnon/ubuntubuild AS builder

# Bitcoin Core
ARG VERSION="v28.1"
ARG GITREPO="https://github.com/bitcoin/bitcoin.git"
ARG GITNAME="bitcoin"
ARG COMPILEFLAGS="--disable-tests --disable-bench --enable-cxx --disable-shared --with-pic --disable-wallet --without-gui --without-miniupnpc"
ENV DEBIAN_FRONTEND="noninteractive"

# Get the source from Github
WORKDIR /root
RUN git clone ${GITREPO} --branch ${VERSION}
WORKDIR /root/${GITNAME}
RUN \
    echo "** compile **" \
    && ./autogen.sh \
    && ./configure CXXFLAG="-O2" LDFLAGS=-static-libstdc++ ${COMPILEFLAGS} \
    && make \
    && echo "** install and strip the binaries **" \
    && mkdir -p /dist-files \
    && make install DESTDIR=/dist-files \
    && strip /dist-files/usr/local/bin/* \
    && echo "** removing extra lib files **" \
    && find /dist-files -name "lib*.la" -delete \
    && find /dist-files -name "lib*.a" -delete \
    && cd .. && rm -rf ${GITREPO}

# Final stage
FROM ubuntu:22.04
LABEL maintainer="Michael J. McKinnon <mjmckinnon@gmail.com>"

# Put our entrypoint script in
COPY ./docker-entrypoint.sh /usr/local/bin/

# Copy the compiled files
COPY --from=builder /dist-files/ /

# Install dependencies and cleanup
ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    echo "** update and install dependencies ** " \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       gosu \
       libboost-filesystem1.74.0 \
       libboost-thread1.74.0 \
       libevent-2.1-7 \
       libevent-pthreads-2.1-7 \
       libczmq4 \
    && echo "** cleanup **" \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && rm -rf /tmp/* /var/tmp/*

# Create our bitcoin system account and group
RUN \
    echo "** setup the bitcoin user **" \
    && groupadd -r bitcoin \
    && useradd --no-log-init -m -d /data -r -g bitcoin bitcoin

ENV DATADIR="/data"
EXPOSE 8333
VOLUME /data

USER bitcoin
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bitcoind", "-printtoconsole"]
