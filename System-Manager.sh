#! /usr/bin/env sh
DIREC=`mktemp -d` # After, create like `echo "Hello" > ${DIREC}/a.txt`
tmp=""
USERS="${DIREC}/users.tmp"
TMP_OUTPUT="${DIREC}/tmpoutput"
TMP_OUTPUT2="${DIREC}/tmpoutput2"
TMP_OUTPUT3="${DIREC}/tmpoutput3"
TMP_OUTPUT4="${DIREC}/tmpoutput4"
STDERR_OUTPUT="${DIREC}/stderroutput"
LOCKED_USERS="${DIREC}/locked_users" # should list like: yzlin judge HAH ...
CHOSED=""
CHOSED_NAME=""
HOME="`env | grep ^HOME | sed 's/HOME=//g'`"

# ctrl+c external error
trap "error_handle 2" 2


# handle the external interrupt
error_handle (){
    rm -rf "${DIREC}"
    if [ ${1} -eq 255 ]; then # ESC code
        echo "Esc pressed." >&2
        exit 1
    elif [ ${1} -eq 2 ]; then # ctrl+c
        echo "Ctrl + C pressed." >&1
        exit 2
    elif [ ${1} -eq 3 ]; then # no sudo permisson
        echo "No sudo permission." >&2
        exit 3
    fi 
}


# sudo permission
test_sudo (){
    tmp=`id -u`
    if [ ${tmp} -ne 0 ]; then
        dialog --msgbox "Please run as root." 20 40
        if [ $? -eq 255 ]; then
            error_handle 255
        fi
        error_handle 3
    fi
}



# Initalize variables
initialize_vars (){
    echo "" > ${TMP_OUTPUT}
    echo "" > ${TMP_OUTPUT2}
    echo "" > ${USERS}
    echo "" > ${LOCKED_USERS}
    tmp=""
}

# System Info Panel
sys_info_panel(){
    dialog --title "System Info Panel" \
        --menu "Please select the command you want to use" 15 40 30 1 "POST ANNOUNCEMENT" 2 "USER LIST" 2>${STDERR_OUTPUT} # 2>&1 > /dev/tty
    if [ $? -eq 255 ]; then
        error_handle 255
    fi
    local ttmp=`cat ${STDERR_OUTPUT}`
    return ${ttmp}
}

post_announcement_panel (){
    dialog --extra-button --extra-label "All" \
        --checklist "POST ANNOUNCEMENT" 20 40 15 `cat ${USERS}` 2>${STDERR_OUTPUT}
    local j=$?
    if [ $j -eq 255 ]; then
        error_handle 255
    fi
    tmp=`cat ${STDERR_OUTPUT}`
    return $j
}

export_panel (){ # use for do export work, input param is the FILE position
    dialog --title "Export to file"\
        --inputbox "Enter the path:" 10 20 2>${STDERR_OUTPUT}
    local j=$?
    if [ $j -eq 255 ]; then
        error_handle 255
    elif [ $j -eq 0 ]; then
        tmp=`cat ${STDERR_OUTPUT}`
        test ${tmp}; j=$?
        if [ ${j} -eq 1 ]; then
            dialog --msgbox "Please input something..." 20 40
            if [ $? -eq 255 ]; then
                error_handle 255
            fi
            return
        fi
        tmp=`echo ${tmp} | sed -r "s:(^[^/]):~/\1:g" | sed "s:~:${HOME}:g"` 
        echo ${tmp} \
            | awk -F "/" 'BEGIN{OFS = "/"}{i=1; while (i < NF){ printf "%s/", $i; i = i+1;}}' > ${TMP_OUTPUT4}
        cat ${TMP_OUTPUT4} | xargs -J % [ -d "%" ]
        local ttmp=$?
        if [ $ttmp -eq 1 ]; then
            dialog --msgbox "Directory `cat ${TMP_OUTPUT3}` doesn't exist." 20 40
            if [ $? -eq 255 ]; then
                error_handle 255;
            fi
            return
        fi 
        echo "" > "${tmp}"
        cat ${1} > "${tmp}"
    fi
}

user_list_panel (){
    initialize_vars
    
    while true; do

    cat /etc/passwd \
        | grep '[0-9]' \
        | awk -F ":" '{if ($NF != "/usr/sbin/nologin") printf "%s %s\n", $3, $1;}' >> "${USERS}"
    # generate logged users
    who \
        | awk -F " " '{if (ALL[$1] == 0) {ALL[$1] = 1;}} END{for (i in ALL) {if ( ! ALL[i] == 0 ) printf "%s ", i;}}' >> ${TMP_OUTPUT}
    for i in `cat ${TMP_OUTPUT}`; do
        sed -i -n -e "s/${i}/${i}[*]/g" ${USERS}
    done
    awk -F " " '{printf "%s %s\n", $2, $1;}' ${USERS} > ${TMP_OUTPUT3}
    echo "" > ${USERS}
    cat ${TMP_OUTPUT3} > ${USERS}
    dialog --ok-label "SELECT" --cancel-label "EXIT" \
        --menu "User Info Panel" 20 40 15 `cat ${USERS}` 2>${STDERR_OUTPUT}
    local j=$?
    if [ ${j} -eq 255 ]; then
        error_handle 255
    elif [ ${j} -eq 0 ]; then # call user action panel
        # remove username
        cat ${STDERR_OUTPUT} | sed -e "s/\[\*\]//g" > ${TMP_OUTPUT}
        tmp=`cat ${TMP_OUTPUT}`
        # get uid by chosed username
        id `cat ${TMP_OUTPUT}` | sed -E -e 's/uid=([[:digit:]]+)/\1@@/g' | awk -F "@" '{print $1}' > ${TMP_OUTPUT}
    
        CHOSED=`cat ${TMP_OUTPUT}` # passed chosen user
        CHOSED_NAME=${tmp}

        while true; do
        user_action_panel
        local action=$?
        if [ ${action} = 1 ]; then
            break
        else
            action=${tmp}
        fi
        #echo action${action}
        case ${action} in 
            A) # Lock It
                lock_or_unlock
            ;;
            B) # Group Info
                group_info
            ;;
            C) # Port Info
                port_info
            ;;
            D) # Login History
                login_history_info
            ;;
            E) # SUDO log
                sudo_log_info
            ;;
            *)
                echo "Something Wrong !!${action}"
            ;;
        esac
        done
    elif [ $? -eq 1 ]; then #jump to main event loop
        break
    fi

    done
}

sudo_log_info (){
    initialize_vars
    while true; do

    date | awk -F " " '{print $2}' > ${TMP_OUTPUT}
    date | awk -F " " '{print $3}' > ${TMP_OUTPUT2}
    
    local a=`cat ${TMP_OUTPUT}`
    local b=`cat ${TMP_OUTPUT2}`
    
    # generte sudo command
    sudo cat /var/log/auth.log \
        | sed -E -e 's/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[[:space:]]*([[:digit:]]*) ([[:digit:]][[:digit:]]:[[:digit:]][[:digit:]]:[[:digit:]][[:digit:]])/\1====\2====\3====/g; s/sudo\[.*\]: */====/g; s/ : /====/g; s/COMMAND=/====/g;' \
        | awk -v now=${a} -v day=${b} -v name=${CHOSED_NAME} -F "====" 'BEGIN{Month["Jan"]="01"; Month["Feb"]="02"; Month["Mar"]="03"; Month["Apr"]="04"; Month["May"]="05"; Month["Jun"]="06"; Month["Jul"]="07"; Month["Aug"]="08"; Month["Sep"]="09"; Month["Oct"]="10"; Month["Nov"]="11"; Month["Dec"]="12"; 
            now=Month[now]; if (now > 1) {last=now-1;} else {last=12;}} 
            {  if (NF == 7 && ((Month[$1] == last && $2 >= day) || (Month[$1] == now)) && $5 == name) 
            {$2 = ($2 < 10) ? "0"$2: $2; print $5 " used sudo to do `" $7 "` on 2021-" Month[$1] "-" $2 " " $3;}}' > ${TMP_OUTPUT3}
    
    dialog --title "SUDO LOG" \
            --extra-button --extra-label "EXPORT" \
            --textbox ${TMP_OUTPUT3} 30 80
    local j=$?
    if [ $j -eq 255 ]; then
        error_handle 255
    elif [ $j = 3 ]; then
        export_panel ${TMP_OUTPUT3}
    else
        break
    fi

    done
}

# User List and Login Panel
login_history_info (){
    initialize_vars
    while true; do

    last ${CHOSED_NAME} | awk -v usr=${CHOSED_NAME} -F " " 'BEGIN{limit=10;} {if (NF == 10) { if ($1 == usr) { if (NR == 1) {print "DATE IP";} if (NR <= limit) {print $4, $5, $6, $7, $3;} } } else { limit = limit + 1; } }' > ${TMP_OUTPUT}
    dialog --title "LOGIN HISTORY" \
            --yes-label "OK" --no-label "EXPORT" \
            --yesno "`cat ${TMP_OUTPUT}`" 20 50
    local j=$?
    if [ $j -eq 255 ]; then
        error_handle 255
    elif [ $j -eq 1 ]; then
        export_panel ${TMP_OUTPUT}
    else
        break
    fi

    done
}

port_info (){
    initialize_vars
    while true; do

    sockstat -4 | grep "${CHOSED_NAME}" | awk -F " " '{printf "%s %s_%s ", $3, $5, $6}' > ${TMP_OUTPUT}
    
    local list=`cat ${TMP_OUTPUT}`
    local j=""
    if [ "${list}" = "${j}" ]; then
        dialog --msgbox "No current port..." 20 40
        if [ $? -eq 255 ]; then
            error_handle 255
        fi
        break
    fi

    # Sock and Port state
    dialog --title "Port Info(PTD and Port)" \
        --menu "" 20 40 15 `echo ${list:="None None"}` 2>${STDERR_OUTPUT}
    j=$?
    tmp=`cat ${STDERR_OUTPUT}`
    if [ $j -eq 255 ]; then
        error_handle 255
    elif [ $j -eq 0 ]; then
        ps -p ${tmp} -u | awk '{if (NR == 1){print $0} }' > ${TMP_OUTPUT}
        ps -p ${tmp} -u | awk '{if (NR == 2){print $0} }' > ${TMP_OUTPUT2}
        now=`cat ${TMP_OUTPUT}`
        local c=1
        echo "" > ${TMP_OUTPUT3}
        for i in ${now}; do
            awk -v var=${c} -v output=${i} -F " " \
                '{if (var == 11) {a=var; printf "%s ", output; while (a <= NF) {printf "%s ", $a; a+=1;} } else if (var < 5 || var > 8) {print output " " $var}}' >> ${TMP_OUTPUT3} \
                ${TMP_OUTPUT2}
            c=$((${c}+1))
        done

        # Process stat with ps command
        dialog --title "PROCESS STATE: ${tmp}" \
            --yes-label "OK" --no-label "EXPORT" \
            --yesno "`cat ${TMP_OUTPUT3}`" 20 50
        j=$?
        echo $j
        if [ $j -eq 255 ]; then
            error_handle 255
        elif [ $j -eq 1 ]; then
            export_panel ${TMP_OUTPUT3}
        fi
    else
        break  
    fi

    done
}

user_action_panel (){
    initialize_vars
    is_locked="LOCK"
    local j="locked"
    sudo cat /etc/master.passwd \
        | grep -s ${CHOSED_NAME} \
        | awk -F "*" '{if ($2 == "LOCKED") {print "locked";} else {print "open"};}' > ${TMP_OUTPUT:="open"}
         
    # cat ${TMP_OUTPUT}
    if [ `cat ${TMP_OUTPUT}` = ${j} ]; then
        is_locked="UNLOCK"
    fi
    dialog --title "${CHOSED_NAME}" \
        --ok-label "SELECT" --cancel-label "EXIT" \
        --menu "User Vagrant" 20 40 15 A "${is_locked} IT" B "GROUP INFO" C "PORT INFO" D "LOGIN HISTORY" E "SUDO LOG" 2>${STDERR_OUTPUT}
    local j=$?
    if [ $j -eq 255 ]; then
        error_handle 255
    fi
    tmp=`cat ${STDERR_OUTPUT}`
    return $j
}

lock_or_unlock (){
    local j="LOCK"
    dialog  --title "${is_locked} it" \
        --yesno "Are you sure you want to do this?" 20 40 2>${STDERR_OUTPUT}
    local jj=$?
    if [ ${jj} -eq 255 ]; then
        error_handle 255
    fi
    tmp=${jj}
    if [ ${tmp} -eq 0 ]; then
        if [ ${is_locked} = ${j} ]; then
            # echo "Lock"
            sudo pw lock ${CHOSED_NAME}
            dialog --msgbox "LOCK SUCCEED!" 20 40
        else
            # echo "Unlock"
            sudo pw unlock ${CHOSED_NAME}
            dialog --msgbox "UNLOCK SUCCEED!" 20 40
        fi
        if [ $? -eq 255 ]; then
            error_handle 255
        fi
    fi
}

group_info(){
    initialize_vars
    echo "GROUP_ID GROUP_NAME" > ${TMP_OUTPUT}
    local own_groups=`groups ${CHOSED_NAME}`
    for g in ${own_groups}; do
        cat /etc/group | grep ^${g} | awk -F ":" '{print $3, $1;}' >> ${TMP_OUTPUT}
    done
    while true; do
        dialog --title "GROUP" \
            --yes-label "OK" --no-label "EXPORT" \
            --yesno "`cat ${TMP_OUTPUT}`" 20 50
        tmp=$?
        if [ ${tmp} -eq 255 ]; then
            error_handle 255
        elif [ ${tmp} -eq 0 ]; then
            break
        elif [ ${tmp} -eq 1 ]; then
            export_panel ${TMP_OUTPUT}
        fi
    done
}

# Post Announcement
post_anouncement(){
    initialize_vars
    cat /etc/passwd \
        | grep '[0-9]' \
        | awk -F ":" '{if ($NF != "/usr/sbin/nologin") printf "%s %s off ", $3, $1;}' >> "${USERS}"
    post_announcement_panel
    local dia_res=$?
    # $? to get exit state of dialog
    if [ ${dia_res} = 3 ]; then # choose all
        chosen_user=`cat ${USERS} | awk -F " " 'BEGIN{i=1;} {while(i < NF) {printf "%s ", $(i+1); i += 3;}}'`
    elif [ ${dia_res} = 1 ]; then
        return 5
    else
        # seperate and compare output
        echo "" > ${TMP_OUTPUT}
        cat ${USERS} | awk -F " " 'BEGIN{i=1;} {while(i < NF) {print $i, $(i+1); i += 3;}}' >> ${TMP_OUTPUT}
        chosen_user=""
        for i in ${tmp}; do
            chosen_user="`awk -v var=${i} -F " " '{if ($1 == var) printf "%s ", $2;}' ${TMP_OUTPUT}`${chosen_user}" 
        done
    fi

    # accept write
    tmp=`dialog --title "Post an announcement" \
        --inputbox "Enter your message: " 20 40 2>&1 > /dev/tty`
    local j=$?
    if [ $j = 255 ]; then
        error_handle 255
    elif [ ${j} = 0 ]; then
        echo ${tmp} > ${TMP_OUTPUT}
        if [ ${dia_res} = 3 ]; then
            wall ${TMP_OUTPUT}
        else
            # create new group, broadcast, then delete the new group
            sudo pw groupdel forcommunica12341234qE_ti_on 2> "/dev/null"
            sudo pw groupadd forcommunica12341234qE_ti_on
            for user in ${chosen_user}; do
                sudo pw groupmod forcommunica12341234qE_ti_on -m ${user}
            done
            wall -g forcommunica12341234qE_ti_on ${TMP_OUTPUT}
            sudo pw groupdel forcommunica12341234qE_ti_on
        fi
    fi
}



# main Event Loop
while true; do
    sys_info_panel
    TMP=$?

    if [ ${TMP:=-1} = "1" ];
    then
        post_anouncement
        # break
        continue
    elif [ ${TMP} = "2" ];
    then
        user_list_panel
        # break
        continue
    else
        dialog --clear
        break
    fi
    dialog --clear
done



# Remove tmp directory
rm -rf "${DIREC}"
echo "Exit."
exit 0