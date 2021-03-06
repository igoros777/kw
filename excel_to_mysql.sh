#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                   Igor Os
#                               igor@igoros.com
#                               www.igoros.com
#                                 2021-01-22
# ----------------------------------------------------------------------------
# Convert a basix Excel spreadsheet into a database table
# ----------------------------------------------------------------------------

while getopts ":f:h:d:u:p:t:" OPTION
do
	case "${OPTION}" in
    f)
			datafilexls="${OPTARG}" ;;
		h)
			db_host="${OPTARG}" ;;
		d)
			db_name="${OPTARG}" ;;
    u)
  		db_user="${OPTARG}" ;;
    p)
  		db_pass="${OPTARG}" ;;
    t)
      tbl_name="${OPTARG}" ;;
		\? ) echo "Unknown option: -$OPTARG" >&2; usage;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; usage;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; usage;;
	esac
done

help() {
	this_script=$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")
cat << EOF
	SYNTAX:
		${this_script} -f /path/to/spreadsheet.xlsx -d <db_name> [-u <db_user>] [-h <db_host>] [-p <db_pass>] [-t <table_name>]
EOF
}

configure() {
  if [ -z "${datafilexls}" ] || [ ! -f "${datafilexls}" ]; then
    help
    exit 11
  else
    datafile="${datafilexls%.*}.csv"
  fi
	if [ ! "${db_name}" ]; then
		help
		exit 15
	fi
	if [ ! "${db_user}" ]; then
		db_user="$(whoami)"
	fi
	if [ ! "${db_host}" ]; then
		db_host="localhost"
	fi
	if [ ! "${db_pass}" ]; then
		echo -n "Enter password for ${db_user}: "
		read -s db_pass
		echo
		if [ ! "${db_pass}" ]; then
			help
			exit 19
		fi
	fi
  if [ ! "${tbl_name}" ]; then
    tbl_name="$(basename "${datafilexls}" | sed -e 's/\./_/g' -e 's/\-/_/g' -e 's/ /_//g')"
    echo "Data will be loaded into ${tbl_name}"
  fi
  tmpdir="/var/tmp"
  if [ ! -d "${tmpdir}" ] ; then mkdir "${tmpdir}" ; fi
  table_create_sql="${tmpdir}/${this_script}_table_create.sql"
  if [ -f "${table_create_sql}" ]; then /bin/rm -f "${table_create_sql}"; fi
  table_load_sql="${tmpdir}/${this_script}_table_load.sql"
  if [ -f "${table_load_sql}" ]; then /bin/rm -f "${table_load_sql}"; fi
  MYSQL="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name} -e"
  MYSQL2="/usr/bin/mysql --batch --skip-column-names --max_allowed_packet=100M -h${db_host} -u${db_user} -p${db_pass} ${db_name}"
}

xls_convert() {
  unoconv -i FilterOptions=44,34,76,2,1/5/2/1/3/1/4/1 -f csv -d spreadsheet -o "${datafile}" "${datafilexls}"
  if [ ! -f "${datafile}" ]; then
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
  sed -e 's/\(.*\)/\L\1/' | sed 's@/@_@g' | sed 's/->/to/g' | sed 's/ $//g' | while read line
  do
    if [ ! -z "${line}" ]
    then
      echo "\`${line}\` VARCHAR(255),"
    else
      echo "\`field_${i}\` VARCHAR(255),"
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
