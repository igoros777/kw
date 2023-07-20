#!/bin/bash
#
#                                      |
#                                  ___/"\___
#                          __________/ o \__________
#                            (I) (G) \___/ (O) (R)
#                                Igor Oseledko
#                           igor@comradegeneral.com
#                                  2023-07-20
# -----------------------------------------------------------------------------
# Identify executable JAR's Java version requirements
# -----------------------------------------------------------------------------
# Change Log:
# *****************************************************************************
# 2023-07-20  igor  Wrote this script
# *****************************************************************************
#V 46:Java 1.2
#V 47:Java 1.3
#V 48:Java 1.4
#V 49:Java 5
#V 50:Java 6
#V 51:Java 7
#V 52:Java 8
#V 53:Java 9
#V 54:Java 10
#V 55:Java 11
#V 56:Java 12
#V 57:Java 13
#V 58:Java 14
#V 59:Java 15
#V 60:Java 16
#V 61:Java 17
configure() {
  this_script_full="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
}

java_match() {
  for f in $(find . -maxdepth 1 -type f -name "*\.jar")
  do
    main_class_name="$(unzip -p "${f}" META-INF/MANIFEST.MF | grep "^Main-Class:" | awk '{print $2}' | dos2unix)"
    main_class_path="$(jar -tf "${f}" | grep "${main_class_name}" | awk '(NR==1||length<$1){min=length; shortest=$0} END{print shortest}' | dos2unix)"
    main_class_filename="$(echo "${main_class_path}" | awk -F'/' '{print $NF}')"
    unzip -p "${f}" "${main_class_path}" > "${main_class_filename}"
    major_version="$(javap -verbose -classpath . "${main_class_filename}" | grep 'major version:' | awk '{print $NF}')"
    java_version="$(grep "^#V ${major_version}:" "${this_script_full}" | awk -F':' '{print $NF}')"
    echo -e "${f},\u2192,major version:,${major_version},Java version:,${java_version}"
    /bin/rm "${main_class_filename}"
  done | column -s, -t
}
# -----------------------------------------------------------------------------
# RUNTIME
# \(^_^)/                                      __|__
#                                     __|__ *---o0o---*
#                            __|__ *---o0o---*
#                         *---o0o---*
# -----------------------------------------------------------------------------
configure
java_match
