#!/bin/bash
echo "$(grep -c ^proc /proc/cpuinfo) x$(grep -m1 ^model.name /proc/cpuinfo | awk -F: '{print $2}')"

echo "Making base folder for our test and create a temporary file"
d=/var/tmp/test
mkdir -p $d
cd $d
f=$(mktemp)

echo "Downloading a large text file into the temporary file"
curl -k -s0 -q https://norvig.com/big.txt > $f

echo "Creating a folder structure populated with files, each containing 128KB of random text"
for i in $(seq -w 01 10)
do
  mkdir -p dir_${i}
  echo "Populating dir_${i}"
  for j in $(seq -w 001 100)
  do
    { head -c 128KB <(shuf -n 10000 $f) > ./dir_${i}/file_${j} & } 2>/dev/null 1>&2
    pids+=($!)
  done
done

for pid in ${pids[*]}
do
  wait ${pid} 2>/dev/null 1>&2
done

echo -n "Determine the number of parallel threads based on the available cores: "
p=$(grep -c proc /proc/cpuinfo)
echo $p

echo ""
echo "Running a test with zip"
echo "Before: $(du -s . | awk '{print $1}')"

find . -maxdepth 1 -mindepth 1 -type d -print0 | \
{ time parallel --will-cite --gnu --null -j $p 'zip -r -q {}{.zip,} && /bin/rm -r {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to compress: "$2}'

echo "After: $(du -s . | awk '{print $1}')"
ls *zip | \
{ time parallel --will-cite --gnu -j $(grep -c proc /proc/cpuinfo) 'unzip -q {} && /bin/rm {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to uncompress: "$2}'

echo ""
echo "Running a test with tar/gzip"
echo "Before: $(du -s . | awk '{print $1}')"

find . -maxdepth 1 -mindepth 1 -type d -print0 | \
{ time parallel --will-cite --gnu --null -j $p 'GZIP=-9 tar cfz {}{.tgz,} && /bin/rm -r {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to compress: "$2}'

echo "After: $(du -s . | awk '{print $1}')"
ls *tgz | \
{ time parallel --will-cite --gnu -j $(grep -c proc /proc/cpuinfo) 'tar xfz {} && /bin/rm {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to uncompress: "$2}'

echo ""
echo "Running a test with tar/bzip2"
echo "Before: $(du -s . | awk '{print $1}')"
find . -maxdepth 1 -mindepth 1 -type d -print0 | \
{ time parallel --will-cite --gnu --null -j $p 'BZIP=-9 tar cfj {}{.tbz,} && /bin/rm -r {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to compress: "$2}'

echo "After: $(du -s . | awk '{print $1}')"
ls *tbz | \
{ time parallel --will-cite --gnu -j $(grep -c proc /proc/cpuinfo) 'tar xfj {} && /bin/rm {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to uncompress: "$2}'

echo ""
echo "Running a test with tar/pigz"
echo "Before: $(du -s . | awk '{print $1}')"
find . -maxdepth 1 -mindepth 1 -type d -print0 | \
{ time parallel --will-cite --gnu --null -j $p 'tar cf - {} | pigz -9 -p $p > {}.tar.gz }' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to compress: "$2}'

echo "After: $(du -s . | awk '{print $1}')"
ls *tar.gz | \
{ time parallel --will-cite --gnu -j $(grep -c proc /proc/cpuinfo) 'tar xfz {} && /bin/rm {}' >/dev/null; } 2>&1 | \
grep real | awk '{print "Time to uncompress: "$2}'

echo ""
echo "Removing test folder"
/bin/rm -r $d
