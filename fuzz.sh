#!/usr/bin/env bash

set -e

ORIGIN=`pwd`
AFL_BIN="$ORIGIN/downloads/afl-2.49b/afl-fuzz"
PHP_BIN="$ORIGIN/downloads/php-src/install/bin/php"

# Fuzzer configuration vars
MEM_LIMIT="none"
SEEDS="$ORIGIN/aux/seeds/"
DRIVER="$ORIGIN/aux/driver.php"
DICTIONARY="$ORIGIN/aux/dictionary.txt"
OUTPUT_DIR="afl_working_dir"

SCREEN_SESS_NAME="fuzz"
SLAVE_COUNT=1

CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)

if [[ ! "$#" -eq 2 ]]; then
	echo "[!] Usage: fuzz.sh outputdir slavecount"
	exit 1
fi

OUTPUT_DIR=$1
SLAVE_COUNT=$2

if [[ "$SLAVE_COUNT" -gt "$((CPU_COUNT - 1))" ]]; then
	echo "[!] You do not have enough cores to run that many slaves"
	exit 1
fi

if [[ ! -f "$AFL_BIN" || ! -f "$PHP_BIN" ]]; then
	echo -n "[!] The AFL or PHP binaries are missing. Run get.sh and "
	echo "build.sh first."
	exit 1
fi
	
if ! hash screen 2>/dev/null; then
	echo "[!] GNU screen is not installed"
	exit 1
fi

echo "[+] Starting AFL (using $OUTPUT_DIR as the output directory) ..."
CMD="USE_ZEND_ALLOC=0 $AFL_BIN -m $MEM_LIMIT -i $SEEDS -o $OUTPUT_DIR "
CMD="${CMD}-x $DICTIONARY -M master -- $PHP_BIN $DRIVER @@"
screen -dmAS "$SCREEN_SESS_NAME" -t master -c aux/screenrc bash -ic "$CMD"

for i in $(seq 1 "$SLAVE_COUNT"); do
	echo "[+] Starting slave $i ..."
	NAME="slave$i"
	CMD="USE_ZEND_ALLOC=0 $AFL_BIN -m $MEM_LIMIT -i $SEEDS -o $OUTPUT_DIR "
	CMD="${CMD}-x $DICTIONARY -S $NAME -- $PHP_BIN $DRIVER @@"
	screen -S "$SCREEN_SESS_NAME" -X screen -t "$NAME" bash -ic "$CMD"
done

echo "[+] Fuzzing started. Attach via 'screen -r $SCREEN_SESS_NAME'"
