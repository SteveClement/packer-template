#!/usr/bin/env bash

# Latest version of packer-template
VER='master'
# Latest commit hash of packer-template
LATEST_COMMIT=$(curl -s https://api.github.com/repos/SteveClement/packer-template/commits  |jq -r '.[0] | .sha')
# Update time-stamp and make sure file exists
touch /tmp/template-latest.sha
# SHAsums to be computed
SHA_SUMS="1 256 384 512"

PACKER_NAME="template"
PACKER_VM="TEMPLATE"
NAME="packer-template"

# Configure your user and remote server
REMOTE=0
REL_USER="template-release"
REL_SERVER="templateServerFQDN"

# GPG Sign
GPG_ENABLED=0
GPG_KEY="0x9BE4AEE9"

# Enable debug for packer, omit -debug to disable
##PACKER_DEBUG="-debug"

# Enable logging for packer
PACKER_LOG=1

# Make sure we have a current work directory
PWD=`pwd`

# Make sure log dir exists (-p quiets if exists)
mkdir -p ${PWD}/log

vm_description='packer-template is a template to check the packer VM generation.'
vm_version="${VER}"

# Fetching latest LookyLoo LICENSE
/usr/bin/wget -q -O /tmp/LICENSE-template https://raw.githubusercontent.com/SteveClement/packer-template/master/LICENSE


# Place holder, this fn() should be used to anything signing related
function signify()
{
if [ -z "$1" ]; then
  echo "This function needs an arguments"
  exit 1
fi

}

function removeAll()
{
  # Remove files for next run
  rm -r output-virtualbox-iso
  rm -r output-vmware-iso
  rm *.checksum *.zip *.sha*
  rm ${PACKER_NAME}-deploy.json
  rm packer_virtualbox-iso_virtualbox-iso_sha1.checksum.asc
  rm packer_virtualbox-iso_virtualbox-iso_sha256.checksum.asc
  rm packer_virtualbox-iso_virtualbox-iso_sha384.checksum.asc
  rm packer_virtualbox-iso_virtualbox-iso_sha512.checksum.asc
  rm ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.asc
}

removeAll

# Check if latest build is still up to date, if not, roll and deploy new
if [ "${LATEST_COMMIT}" != "$(cat /tmp/${PACKER_NAME}-latest.sha)" ]; then

  echo "Current packer-${PACKER_NAME} version is: ${VER}@${LATEST_COMMIT}"

  # Search and replace for vm_name and make sure we can easily identify the generated VMs
  cat ${PACKER_NAME}.json| sed "s|\"vm_name\": \"${PACKER_VM}_demo\",|\"vm_name\": \"${PACKER_VM}_${VER}@${LATEST_COMMIT}\",|" > ${PACKER_NAME}-deploy.json

  # Build virtualbox VM set
  PACKER_LOG_PATH="${PWD}/log/packerlog-vbox.txt"
  /usr/local/bin/packer build ${PACKER_DEBUG} -var "vm_description=${vm_description}" -var "vm_version=${vm_version}" -only=virtualbox-iso ${PACKER_NAME}-deploy.json

  # Build vmware VM set
  PACKER_LOG_PATH="${PWD}/log/packerlog-vmware.txt"
  /usr/local/bin/packer build ${PACKER_DEBUG} -var "vm_description=${vm_description}" -var "vm_version=${vm_version}" -only=vmware-iso ${PACKER_NAME}-deploy.json

  # ZIPup all the vmware stuff
  zip -r ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip  packer_vmware-iso_vmware-iso_sha1.checksum packer_vmware-iso_vmware-iso_sha512.checksum output-vmware-iso

  # Create a hashfile for the zip
  for SUMsize in `echo ${SHA_SUMS}`; do
    shasum -a ${SUMsize} *.zip > ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.sha${SUMsize}
  done


  # Current file list of everything to gpg sign and transfer
  FILE_LIST="${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip output-virtualbox-iso/${PACKER_VM}_${VER}@${LATEST_COMMIT}.ova packer_virtualbox-iso_virtualbox-iso_sha1.checksum packer_virtualbox-iso_virtualbox-iso_sha256.checksum packer_virtualbox-iso_virtualbox-iso_sha384.checksum packer_virtualbox-iso_virtualbox-iso_sha512.checksum ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.sha1 ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.sha256 ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.sha384 ${PACKER_VM}_${VER}@${LATEST_COMMIT}-vmware.zip.sha512"

  # Create the latest ${NAME} export directory
  ##ssh ${REL_USER}@${REL_SERVER} mkdir -p export/${PACKER_VM}_${VER}@${LATEST_COMMIT}

  # Sign and transfer files
  for FILE in ${FILE_LIST}; do
    gpg --local-user ${GPG_KEY} --armor --output ${FILE}.asc --detach-sig ${FILE}
    if [ "${REMOTE}" != "0" ]; then
        echo "Uploading to ${REL_USER}@${REL_SERVER}"
        ##rsync -azv --progress ${FILE} ${REL_USER}@${REL_SERVER}:export/${PACKER_VM}_${VER}@${LATEST_COMMIT}
        ##rsync -azv --progress ${FILE}.asc ${REL_USER}@${REL_SERVER}:export/${PACKER_VM}_${VER}@${LATEST_COMMIT}
        ##ssh ${REL_USER}@${REL_SERVER} rm export/latest
        ##ssh ${REL_USER}@${REL_SERVER} ln -s ${PACKER_VM}_${VER}@${LATEST_COMMIT} export/latest
        ##ssh ${REL_USER}@${REL_SERVER} chmod -R +r export
    fi
  done

  # The following was an attempt to have a prettier index. Replaced with "fancy-index"
  ##ssh ${REL_USER}@${REL_SERVER} cd export ; tree -T "packer-template VM Images" -H https://www.circl.lu/template-images/ -o index.html

  echo ${LATEST_COMMIT} > /tmp/${PACKER_NAME}-latest.sha
else
  echo "Current ${NAME} version ${VER}@${LATEST_COMMIT} is up to date."
fi
