ARG REGISTRY=registry.internal
ARG STACK=cloudfoundry/cflinuxfs3
ARG STACK_FIN=cflinuxfs2
ARG VERSION=latest
ARG VERSION_FIN=latest
ARG STACK_FULL=${REGISTRY}/$STACK:$VERSION
ARG STACK_FULL_FIN=${REGISTRY}/$STACK_FIN:$VERSION_FIN
FROM $STACK_FULL as stage1
RUN  apt-get -y install software-properties-common
RUN  apt-get -y -qq update 
RUN  apt-get -y install golang btrfs-tools git libapparmor-dev libdevmapper-dev autogen autotools-dev automake libtool libostree-dev ostree libgpgme-dev
RUN  git clone https://github.com/projectatomic/skopeo ~/go/src/github.com/projectatomic/skopeo
RUN  cd ~/go/src/github.com/projectatomic/skopeo; make binary-local-static BUILDTAGS='containers_image_openpgp containers_image_ostree_stub containers_image_storage_stub'
RUN  go get -d github.com/openSUSE/umoci; cd ~/go/src/github.com/openSUSE/umoci; make 

FROM $STACK_FULL_FIN
COPY --from=stage1 /root/go/src/github.com/projectatomic/skopeo/skopeo /usr/local/bin/skopeo
COPY --from=stage1 /root/go/src/github.com/openSUSE/umoci/umoci /usr/local/bin/umoci
COPY policy.json /etc/containers/policy.json
