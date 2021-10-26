#!/stage/1/bin/ash
set -uex

PATH=/stage/1/bin

echo 'Hi from stage 2!' | sed s/Hi/Hello/
ls

exit 0
