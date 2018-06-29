ARG REGISTRY=registry.internal
ARG STACK=cloudfoundry/cflinuxfs3
ARG STACK_FIN=cflinuxfs2
ARG VERSION=latest
ARG VERSION_FIN=latest
ARG STACK_FULL=${REGISTRY}/$STACK:$VERSION
ARG STACK_FULL_FIN=${REGISTRY}/$STACK_FIN:$VERSION_FIN
FROM $STACK_FULL as stage1
#RUN  apt-get -y install software-properties-common
#RUN  apt-get -y -qq update 
RUN  apt-get -y install golang btrfs-tools git libapparmor-dev libdevmapper-dev autogen autotools-dev automake libtool libostree-dev ostree libgpgme-dev
RUN  git clone https://github.com/projectatomic/skopeo ~/go/src/github.com/projectatomic/skopeo
RUN  cd ~/go/src/github.com/projectatomic/skopeo; make binary-local-static BUILDTAGS='containers_image_openpgp containers_image_ostree_stub containers_image_storage_stub'
RUN  go get -d github.com/openSUSE/umoci; cd ~/go/src/github.com/openSUSE/umoci; make 

FROM $STACK_FULL_FIN as stage2

ENV GOPATH /go
ENV GOBIN /go/bin
RUN /bin/bash -c '\
  mkdir -p /usr/local/ && \
  URL=https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz && \
  curl -s -L --retry 15 --retry-delay 2 $URL -o /tmp/go.tar.gz && \
  tar xzf /tmp/go.tar.gz -C /usr/local/ && \
  rm /tmp/go.tar.gz'

ENV PATH $GOBIN:/usr/local/go/bin:$PATH
RUN go get github.com/onsi/ginkgo/ginkgo && go get github.com/onsi/gomega
RUN git clone https://github.com/cloudfoundry/buildpackapplifecycle.git /go/src/code.cloudfoundry.org/buildpackapplifecycle/

WORKDIR /go/src/
RUN go get ./...


FROM $STACK_FULL_FIN
COPY --from=stage1 /root/go/src/github.com/projectatomic/skopeo/skopeo /usr/local/bin/skopeo
COPY --from=stage1 /root/go/src/github.com/openSUSE/umoci/umoci /usr/local/bin/umoci
COPY --from=stage2 /go/bin/* /usr/local/bin/
COPY policy.json /etc/containers/policy.json
RUN apt-get -y install guile-2.0
RUN cd /root; git clone https://github.com/ChaosEternal/guile-scsh.git
RUN cd /root/guile-scsh; git checkout guile-209-fix; guile --no-auto-compile install.scm
