#!/bin/bash
set -euxo pipefail

SSH_OPTS="-l jenkins_aos_cd_bot -o StrictHostKeychecking=no use-mirror-upload.ops.rhcloud.com"
KN_VERSION=${1}
KN_URL=${2}
LINUX_PLATFORMS=(linux-amd64 linux-arm64 linux-ppc64le linux-s390x)

# check if already exists
### TODO: figure out why the script exits regardless of test result when this is uncommented:
#if ssh ${SSH_OPTS} "[ -d /srv/pub/openshift-v4/clients/serverless/${KN_VERSION} ]"
#then
#    echo "Already have latest version"
#    exit 0
#fi
echo "Fetching Knative client ${KN_VERSION} binaries"

OUTDIR=$(mktemp -dt knbinary.XXXXXXXXXX)
trap "rm -rf '${OUTDIR}'" EXIT INT TERM

pkg_tar() {
    local dir
    case "$1" in
        linux-*) dir=${1};;
        macos) dir=macos-amd64;;
    esac
    cp ./LICENSE ${OUTDIR}/${dir}
    tar --owner 0 --group 0 -C ${OUTDIR}/${dir} . -zcf ./kn-${dir}-${KN_VERSION}.tar.gz
}


pushd ${OUTDIR}
for platform in ${LINUX_PLATFORMS[*]}
do
    mkdir ${platform}
    wget "${KN_URL}/signed/linux/kn-${platform}" -O ${platform}/kn
    chmod +x ${platform}/kn
done
mkdir macos-amd64 windows
wget "${KN_URL}/signed/macos/kn-darwin-amd64" -O macos-amd64/kn
wget "${KN_URL}/signed/windows/kn-windows-amd64.exe" -O windows/kn.exe
wget https://raw.githubusercontent.com/openshift/knative-client/master/LICENSE
chmod +x {linux,macos}-*/kn

for platform in ${LINUX_PLATFORMS[*]}
do
    pkg_tar ${platform}
done
pkg_tar macos
cp ./LICENSE ${OUTDIR}/windows/
zip --quiet --junk-path - ${OUTDIR}/windows/* > "${OUTDIR}/kn-windows-amd64-${KN_VERSION}.zip"

sha256sum kn-* > sha256sum.txt
mkdir ${KN_VERSION}
mv *.tar.gz *.zip sha256sum.txt ${KN_VERSION}
ln -sf ${KN_VERSION} latest

# sync to use-mirror-upload
rsync \
    -av --delete-after --progress --no-g --omit-dir-times --chmod=Dug=rwX \
    -e "ssh -l jenkins_aos_cd_bot -o StrictHostKeyChecking=no" \
    "${KN_VERSION}" latest \
    use-mirror-upload.ops.rhcloud.com:/srv/pub/openshift-v4/clients/serverless/

popd

# kick off mirror push for serverless dir
ssh ${SSH_OPTS} << EOF
    timeout 15m /usr/local/bin/push.pub.sh openshift-v4/clients/serverless -v \
    || timeout 5m /usr/local/bin/push.pub.sh openshift-v4/clients/serverless -v \
    || timeout 5m /usr/local/bin/push.pub.sh openshift-v4/clients/serverless -v
EOF
