#!/bin/bash
string="  \\\\    location ~ /.git/ { \n \\treturn 444; \n \\   }"
function findServerBlock () {
    if [[  $1 =~ ^server && $1 != server_name ]]; then
        return 0
    else
        return 1
    fi
}
function main() {
    i=1
    conunt=0
    while read line; do  
        findServerBlock $line
        if [ $? -eq 0 ]; then
            echo $i
            conunt=$((conunt+1))
            if [ $conunt -eq 1 ]; then
                sed -i "$((i+1)) i $string" $1
            else
                sed -i "$((i+4)) i $string" $1
            fi
        fi
        i=$((i+1))  

    done < $1
}
main $1