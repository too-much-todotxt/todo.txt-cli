#!/bin/bash

version() { sed -e 's/^    //' <<EndVersion
        TODO.TXT Manager
        Version 1.6.3
        Author:  Gina Trapani (ginatrapani@gmail.com)
        Release date:  5/11/2006
        Last updated:  7/6/2006
        License:  GPL, http://www.gnu.org/copyleft/gpl.html
        More information and mailing list at http://todotxt.com
EndVersion
    exit 1
}

usage()
{ 
    sed -e 's/^    //' <<EndUsage
      Usage: $0 [options] [ACTION] [PARAM...]

      Actions:
        add "THING I NEED TO DO p:project @context"
          Adds TODO ITEM to your todo.txt.
          Project and context notation optional.
          Quotes optional.

        append NUMBER "TEXT TO APPEND"
          Adds TEXT TO APPEND to the end of the todo on line NUMBER.
          Quotes optional.

        archive
          Moves done items from todo.txt to done.txt.

        del NUMBER
          Deletes the item on line NUMBER in todo.txt.

        do NUMBER
          Marks item on line NUMBER as done in todo.txt.

        list [TERM] [[TERM]...]
          Displays all todo's that contain TERM(s) sorted by priority with line
          numbers.  If no TERM specified, lists entire todo.txt.

        listpri [PRIORITY]
          Displays all items prioritized PRIORITY.
          If no PRIORITY specified, lists all prioritized items.

        prepend NUMBER "TEXT TO PREPEND"
          Adds TEXT TO PREPEND to the beginning of the todo on line NUMBER.
          Quotes optional.

        pri NUMBER PRIORITY
          Adds PRIORITY to todo on line NUMBER.  If the item is already 
	   prioritized, replaces current priority with new PRIORITY.
	   PRIORITY must be an uppercase letter between A and Z.

        replace NUMBER "UPDATED TODO"
          Replaces todo on line NUMBER with UPDATED TODO.

        remdup
          Removes exact duplicate lines from todo.txt.

        report
          Adds the number of open todo's and closed done's to report.txt.

      Options:
        -d CONFIG_FILE
            Use a configuration file other than the default ~/.todo
        -p
            Plain mode, turns off colors
        -q 
            Quiet mode, muffles chatty confirmation messages
        -V 
            Displays version, license and credits.
EndUsage

    exit 1
}

die()
{
    echo "$*"
    exit 1
}

cleanup()
{
    [ -f "$TMP_FILE" ] && rm "$TMP_FILE"
    exit 0
}


# == PROCESS OPTIONS ==
# defaults
QUIET=0
PLAIN=0
CFG_FILE=$HOME/.todo

while getopts ":pqVd:" Option
do
  case $Option in
    p )
	PLAIN=1 
	;;
    q ) 
	QUIET=1
	;;
    d)  
	CFG_FILE=$OPTARG
	;;
    V)
	version
	;;
  esac
done
shift $(($OPTIND - 1))

# === SANITY CHECKS (thanks Karl!) ===
[ -r "$CFG_FILE" ] || die "Fatal error:  Cannot read configuration file $CFG_FILE"

. "$CFG_FILE"

[ -z "$1" ]         && usage
[ -d "$TODO_DIR" ]  || die "Fatal Error: $TODO_DIR is not a directory"  
cd "$TODO_DIR"      || die "Fatal Error: Unable to cd to $TODO_DIR"

echo '' > "$TMP_FILE" || die "Fatal Error:  Unable to write in $TODO_DIR"  
[ -f "$TODO_FILE" ] || cp /dev/null "$TODO_FILE"
[ -f "$DONE_FILE" ] || cp /dev/null "$DONE_FILE"
[ -f "$REPORT_FILE" ] || cp /dev/null "$REPORT_FILE"


if [ $PLAIN = 1 ]; then
	PRI_A=$NONE
	PRI_B=$NONE
	PRI_C=$NONE
	PRI_X=$NONE
	DEFAULT=$NONE
fi

# === HEAVY LIFTING ===
shopt -s extglob

# == HANDLE ACTION ==
action=$1

case $action in 
"add" )
	[ -z "$2" ] && die "usage: $0 add \"TODO ITEM\""
	shift

	echo "$*" >> "$TODO_FILE"
	TASKNUM=$(wc -l "$TODO_FILE" | sed 's/^[[:space:]]*\([0-9]*\).*/\1/')
	[[ $QUIET = 1 ]] || echo "TODO: '$*' added on line $TASKNUM."
	cleanup;;

"append" )
	errmsg="usage: $0 append ITEM# \"TEXT TO APPEND\""
	shift; item=$1; shift

	[ -z "$item" ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"

        # made the sed delimiter a pipe | b/c you might want to add text with slashes, like a URL
        # TODO: check if incoming text contains a pipe and escape it
	if sed -ne "$item p" "$TODO_FILE" | grep "^."; then
		if sed -i.bak $item" s|^.*|& $*|" "$TODO_FILE"; then
		        NEWTODO=$(sed "$item!d" "$TODO_FILE")
		        [[ $QUIET = 1 ]] || echo "$item: $NEWTODO"
		else
			echo "TODO:  Error appending task $item."
		fi
	else
		echo "$item: No such todo."
	fi
	cleanup;;

"archive" )
	[[ $QUIET = 1 ]] || grep "^x " "$TODO_FILE"
	grep "^x " "$TODO_FILE" >> "$DONE_FILE"
	sed -i.bak '/^x /d' "$TODO_FILE"
        [[ $QUIET = 1 ]] || echo "--"
        [[ $QUIET = 1 ]] || echo "TODO:  Items marked as done have been moved from $TODO_FILE to $DONE_FILE."
	cleanup;;

"del" )
	errmsg="usage: $0 del ITEM#"
	item=$2
	[ -z "$item" ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"
	if sed -ne "$item p" "$TODO_FILE" | grep "^."; then
		DELETME=$(sed "$2!d" "$TODO_FILE")
	        echo "Delete '$DELETME'?  (y/n)"
		read ANSWER
	        if [ "$ANSWER" = "y" ]; then
		       sed -i.bak -e $2"s/^.*//" -e '/./!d' "$TODO_FILE"
		       [[ $QUIET = 1 ]] || echo "TODO:  '$DELETME' deleted."
		       cleanup
		else
			echo "TODO:  No tasks were deleted."
		fi
	else
		echo "$item: No such todo."
        fi ;;

"do" )
	errmsg="usage: $0 do ITEM#"
	item=$2
	[ -z "$item" ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"

	if sed -ne "$item p" "$TODO_FILE" | grep "^."; then
		now=`date '+%Y-%m-%d'`
		sed -i.bak $2"s|^|&x $now |" "$TODO_FILE"
		NEWTODO=$(sed "$2!d" "$TODO_FILE")
	        [[ $QUIET = 1 ]] || echo "$item: $NEWTODO"
	        [[ $QUIET = 1 ]] || echo "TODO: $item marked as done."
		cleanup
	else
		echo "$item:  No such todo."
	fi ;;

"list" )
	item=$2
	if [ -z "$item" ]; then
		# Now in COLOR!  with padding!
		echo -e "`sed = "$TODO_FILE" | sed 'N; s/^/  /; s/ *\(.\{2,\}\)\n/\1 /' | sed 's/^ /0/' | sort -k2 | sed 's/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g' | sed 's/\(.*(B).*\)/'$PRI_B'\1'$'/g' | sed 's/\(.*(C).* \)/'$PRI_C'\1'$'/g' | sed 's/\(.*([A-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g'`"

		echo "--"
		NUMTASKS=$(wc -l "$TODO_FILE" | sed 's/^[[:space:]]*\([0-9]*\).*/\1/')
		echo "TODO: $NUMTASKS tasks in $TODO_FILE."
	else
		command=`sed = "$TODO_FILE" | sed 'N; s/^/  /; s/ *\(.\{2,\}\)\n/\1  /' | sed 's/^ /0/' | sort -k2 | sed 's/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g' | sed 's/\(.*(B).*\)/'$PRI_B'\1'$'/g' | sed 's/\(.*(C).*\)/'$PRI_C'\1'$'/g'  |  sed 's/\(.*([A-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g' | grep -i $item `
		shift
		shift
		for i in $*
			do
			command=`echo "$command" | grep -i $i `
			done
		command=`echo "$command" | sort -k2`

		echo -e "$command"
	fi
	cleanup ;;

"listpri" )
	pri=$2
	if [ -z "$pri" ]; then
		echo -e "`sed = "$TODO_FILE" | sed 'N; s/^/  /; s/ *\(.\{2,\}\)\n/\1  /' | sed 's/^ /0/' | sort -k2 |  sed 's/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g' | sed  's/\(.*(B).*\)/'$PRI_B'\1'$'/g' | sed 's/\(.*(C).*\)/'$PRI_C'\1'$'/g'  | sed 's/\(.*([A-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g'`" | grep \([A-Z]\)
	else
		echo -e "`sed = "$TODO_FILE" | sed 'N; s/^/  /; s/ *\(.\{2,\}\)\n/\1  /' | sed 's/^ /0/' |  sort -k2 |  sed 's/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g' | sed  's/\(.*(B).*\)/'$PRI_B'\1'$'/g' | sed 's/\(.*(C).*\)/'$PRI_C'\1'$'/g'  | sed 's/\(.*([A-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g'`" | grep \($pri\)
	fi
	cleanup;;

"prepend" )
	errmsg="usage: $0 prepend ITEM# \"TEXT TO PREPEND\""
	shift; item=$1; shift

	[ -z "$item" ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"

        # made the sed delimiter a pipe | b/c you might want to add text with slashes, like a URL
        # TODO: check if incoming text contains a pipe and escape it
	if sed -ne "$item p" "$TODO_FILE" | grep "^."; then
		if sed -i.bak $item" s|^.*|$* &|" "$TODO_FILE"; then
		        NEWTODO=$(sed "$item!d" "$TODO_FILE")
		        echo "$item: $NEWTODO"
		else
			echo "TODO:  Error prepending task $item."
		fi
	else
		echo "$item: No such todo."
	fi
	cleanup;;
"pri" )
	item=$2
	newpri=$3
	errmsg="usage: $0 pri ITEM# PRIORITY  
note:  PRIORITY must be uppercase to maintain sort order."

	[ "$#" -ne 3 ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"
	[[ "$newpri" = +([A-Z]) ]] || die "$errmsg"

	sed -e $item"s/^(.*) //" -e $item"s/^/($newpri) /" "$TODO_FILE" > /dev/null 2>&1

        if [ "$?" -eq 0 ]; then
		#it's all good, continue
		sed -i.bak -e $2"s/^(.*) //" -e $2"s/^/($3) /" "$TODO_FILE"
                NEWTODO=$(sed "$2!d" "$TODO_FILE")
		[[ $QUIET = 1 ]] || echo -e "`echo "$item: $NEWTODO"`"
                
                [[ $QUIET = 1 ]] || echo "TODO: $item prioritized ($newpri)."
		cleanup
        else
		die "$errmsg"
	fi;;
"remdup" )
	cp "$TODO_FILE" "$TMP_FILE"
	cat "$TMP_FILE" | sed -n 'G; s/\n/&&/; /^\([ -~]*\n\).*\n\1/d; s/\n//; h; P' > "$TODO_FILE"
	[[ $QUIET = 1 ]] || echo "TODO: Duplicate tasks have been removed."
	cleanup;;

"replace" )
	errmsg="usage: $0 replace ITEM# \"UPDATED ITEM\""
	shift; item=$1; shift
	[ -z "$item" ] && die "$errmsg"
	[[ "$item" = +([0-9]) ]] || die "$errmsg"
	
	if sed -ne "$item p" "$TODO_FILE" | grep "^."; then
		# made the sed delimiter a pipe | b/c you might want to add text with slashes, like a URL
		# TODO: check if incoming text contains a pipe and escape it
		sed -i.bak $item" s|^.*|$*|" "$TODO_FILE"
		[[ $QUIET = 1 ]] || NEWTODO=$(head -$item "$TODO_FILE" | tail -1)
		[[ $QUIET = 1 ]] || echo "replaced with"
		[[ $QUIET = 1 ]] || echo "$item: $NEWTODO"
	else
		echo "$item: No such todo."
	fi
	cleanup;;

"report" )
	#archive first
	sed '/^x /!d' "$TODO_FILE" >> $DONE_FILE
	sed -i.bak '/^x /d' "$TODO_FILE"

    NUMLINES=$(wc -l "$TODO_FILE" | sed 's/^[[:space:]]*\([0-9]*\).*/\1/')
    if [ $NUMLINES = "0" ]; then
         echo "datetime todos dones" >> "$REPORT_FILE"
    fi
	#now report
	TOTAL=$(cat "$TODO_FILE" | wc -l | sed 's/^[ \t]*//')
	TDONE=$(cat "$DONE_FILE" | wc -l | sed 's/^[ \t]*//')
	TECHO=$(echo $(date +%Y-%m-%d-%T); echo ' '; echo $TOTAL; echo ' ';
	echo $TDONE)
	echo $TECHO >> "$REPORT_FILE"
	[[ $QUIET = 1 ]] || echo "TODO:  Report file updated."
	cat "$REPORT_FILE"
	cleanup;;
* )
	usage
esac