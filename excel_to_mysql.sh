#!/bin/bash
datafilexls="${1}"
tbl_name="${2}"


configure() {
  if [ -z "${datafilexls}" ] || [ ! -f "${datafilexls}" ]
  then
    echo "Specify valid input filename. Exiting..."
    exit 11
  else
    datafile="${datafilexls%.*}.csv"
  fi
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
  if [ ! "${tbl_name}" ]
  then
    tbl_name="${this_script/\.sh/_tbl}"
    echo "Data will be loaded into ${tbl_name}"
  fi
  tmpdir="/var/tmp"
  if [ ! -d "${tmpdir}" ] ; then mkdir "${tmpdir}" ; fi
  table_create_sql="${tmpdir}/${this_script}_table_create.sql"
  if [ -f "${table_create_sql}" ]; then /bin/rm -f "${table_create_sql}"; fi
  table_load_sql="${tmpdir}/${this_script}_table_load.sql"
  if [ -f "${table_load_sql}" ]; then /bin/rm -f "${table_load_sql}"; fi
  db_host="amidala.wil.csc.local" ; db_user="root" ; db_pass="bh10236" ; db_name="sysinfo"
  MYSQL="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name} -e"
  MYSQL2="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name}"
}

xls_convert() {
  unoconv -i FilterOptions=44,34,76,2,1/5/2/1/3/1/4/1 -f csv -d spreadsheet -o "${datafile}" "${datafilexls}"
  if [ ! -f "${datafile}" ]
  then
    echo "Unable to convert "${datafilexls}" to CSV. Exiting..."
    exit 22
  fi
}

table_drop() {
  ${MYSQL} "DROP TABLE ${tbl_name};"
}

table_create() {
cat << EOF > "${table_create_sql}"
CREATE TABLE ${tbl_name} (
\`id\` INT(11) NOT NULL AUTO_INCREMENT,
  $(i=1; head -1 "${datafile}" | tr , '\n' | sed -r 's/ /_/g' | sed -r 's/[\(\)]//g' | \
  sed -e 's/\(.*\)/\L\1/' | sed 's@/@_@g' | sed 's/->/to/g' | sed 's/fdqn/fqdn/g' | while read line
  do
    if [ ! -z "${line}" ]
    then
      echo "\`${line}\` VARCHAR(45),"
    else
      echo "\`field_${i}\` VARCHAR(45),"
    fi
    (( i = i + 1 ))
  done)
PRIMARY KEY (\`id\`),
UNIQUE INDEX \`id_UNIQUE\` (\`id\` ASC))
ENGINE = MyISAM ;;
EOF

${MYSQL2} < "${table_create_sql}"
}

data_load() {
cat << EOF2 > "${table_load_sql}"
LOAD DATA LOCAL INFILE '${datafile}' INTO TABLE ${tbl_name} \
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES \
(\
$(i=1; head -1 "${datafile}" | tr , '\n' | sed -r 's/ /_/g' | sed -r 's/[\(\)]//g' | \
sed -e 's/\(.*\)/\L\1/' | sed 's@/@_@g' | sed 's/->/to/g' | sed 's/fdqn/fqdn/g' | while read line
do
if [ ! -z "${line}" ]
then
echo -n "${line}, "
else
echo -n "field_${i}, "
fi
(( i = i + 1 ))
done | sed 's/, $//g')
);
EOF2

${MYSQL2} < "${table_load_sql}"
}

# RUNTIME

configure
xls_convert
table_drop 2>/dev/null
table_create
data_load
