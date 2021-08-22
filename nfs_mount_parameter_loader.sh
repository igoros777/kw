#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                 2021-08-22
# ----------------------------------------------------------------------------
# Load output of nfs_mount_parameter_parser.sh
# ----------------------------------------------------------------------------
# Change Log:
# ****************************************************************************
# 2021-08-22	igor	Wrote this script
# ****************************************************************************

configure() {
  this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")" | sed 's/loader/parser/g')
  this_host=$(hostname | awk -F'.' '{print $1}')
  this_time_db=$(date +'%Y-%m-%d %H:%M:%S')
  this_time=$(date -d "${this_time_db}" +'%Y-%m-%d_%H%M%S')
  outdir="/var/tmp/${this_script}"
  if [ ! -d "${outdir}" ]; then mkdir -p "${outdir}"; fi
  if [ ! -z "${1}" ] && [ -f "${1}" ]; then
    outfile="${1}"
  else
    outfile="$(find "${outdir}" -name "${this_script}*\.csv" | sort | tail -1)"
    if [ -z "${outfile}" ] || [ ! -f "${outfile}" ] || [ ! -s "${outfile}" ]
    then
      echo "Input file not found. Exiting..."
      exit 23
    fi
  fi
  }

db_config() {
  table_create_sql="${outdir}/${this_script}_table_create.sql"
  if [ -f "${table_create_sql}" ]; then /bin/rm -f "${table_create_sql}"; fi
  table_load_sql="${outdir}/${this_script}_table_load.sql"
  if [ -f "${table_load_sql}" ]; then /bin/rm -f "${table_load_sql}"; fi

  db_host="your_db_server" ; db_user="your_db_user" ; db_pass="your_db_pass" ; db_name="your_db_name" ; tbl_name="${this_script/\.sh/_tbl}"
  MYSQL="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name} -e"
  MYSQL2="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name}"
}

table_drop() {
  ${MYSQL} "DROP TABLE ${tbl_name};" 2>/dev/null
}

table_create() {
cat << EOF > "${table_create_sql}"
CREATE TABLE ${tbl_name} (
\`id\` INT(11) NOT NULL AUTO_INCREMENT,
  $(i=1; head -1 "${outfile}" | tr , '\n' | sed -r 's/ /_/g' | sed -r 's/[\(\)]//g' | \
  sed -e 's/\(.*\)/\L\1/' | sed 's@/@_@g' | sed 's/ $//g' | while read line
  do
    if [ ! -z "${line}" ]
    then
      if [ "${line}" == "this_time_db" ]
      then
        echo "\`${line}\` DATETIME,"
      else
        echo "\`${line}\` VARCHAR(225),"
      fi
    else
      echo "\`field_${i}\` VARCHAR(225),"
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
LOAD DATA LOCAL INFILE '${outfile}' INTO TABLE ${tbl_name} \
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 LINES \
(\
$(i=1; head -1 "${outfile}" | tr , '\n' | sed -r 's/ /_/g' | sed -r 's/[\(\)]//g' | \
sed -e 's/\(.*\)/\L\1/' | sed 's@/@_@g' | while read line
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

cleanup() {
  find "${outdir}" -type f -name "${this_script}*\.sql" -delete
}

# ----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# ----------------------------------------------------------------------------
configure
db_config
table_drop
table_create
data_load
cleanup
