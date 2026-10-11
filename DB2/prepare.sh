#!/bin/bash
# Create OS user test and grant DBADM on MYCO. Run as root in business-db2.
set -e
if ! id test >/dev/null 2>&1; then
  useradd -m test
fi
if ! echo 'test:dbfit' | chpasswd; then
  usermod -p "$(openssl passwd -6 dbfit)" test
fi
su - db2inst1 -c 'bash -s' << 'EOS'
set -e
. ~/sqllib/db2profile
db2 connect to MYCO
db2 "grant dbadm on database to user test" || true
db2 connect reset
EOS
