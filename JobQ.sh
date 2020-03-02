#!/bin/bash
scriptName="${0##*/}"
declare -i DEFAULT_RUNTYPE=0
declare -i DEFAULT_INFILES=1
declare -i DEFAULT_DELAY=0

declare -i runtype=DEFAULT_RUNTYPE
declare -i innumfiles=DEFAULT_INFILES
declare -i delay=DEFAULT_DELAY

function printUsage() {
    cat <<EOF

Synopsis

    $scriptName [-R] [-i number_of_files] [-d seconds] template

Description

    Generate submission files based on the template for all input files
    template should have \$input for the input file (by default only one input is assumed)
    corresponding output will be the basename without extension and can be reffered as \$output in template.

    -R
        Use the template as it is, without substituting \$input or \$output
        Each line in template file will be used in separate submission file

    -i number_of_files
        Template file has more than one \$input file (number_of_files)
        the input files can be refferred as \$input1, \$input2 ... in template and 
        corresponding output files will be \$output1, \$output2 ...

    -d seconds
        Delay between each job submission in seconds
        by default all jobs will be submitted sequentially wihout any delay

Author

    Arun Seetharam, Bioinformatics Core, Purdue University.
    aseetharam@purdue.edu




EOF
}

while getopts ":R:i:d:" option; do
    case "$option" in
        R) runtype=$OPTARG ;;
        i) innumfiles=$OPTARG ;;
        d) delay=$OPTARG ;;
        *) printUsage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if (($# == 0 || interval <= 0)); then
    printUsage
    exit 1
fi

## Header part---end
ask()
{
  printf "%${2}s" "$3"
  read val
  if [ -z $val ]; then val=$4; fi
  eval $1="$val"
}

queue=standby
nodes=1
processors=8
walltime=4
lmodules=N
if [ -e ~/.jobqvars ]; then
. ~/.jobqvars
fi

flag=n
declare -a nctree

until [ $flag = y -o $flag = Y ]
do
  clear
  echo ""
  echo "          ---- Required Section ----"
  echo ""
  ask queue  51 "Queue name [$queue]: " $queue
  ask nodes  51 "Number of nodes [$nodes]: " $nodes
  ask processors    51 "Number of processors [$processors]: " $processors
  ask walltime    51 "Required walltime (int only) in hrs [$walltime]: " $walltime
  ask lmodules 51 "Load modules? (Y/N) [$lmodules]: " $lmodules
  if [ "$lmodules" = "y" -o "$lmodules" = "Y" ]; then
    ask nctrees 51 "Number of moudles to load: " $nctrees
    if [ $nctrees -gt 0 ]; then
      for ((i=0; i<$nctrees; i++))
      do
        ask nctree[i] 51 "module-- $i: " ${nctree[i]}
      done
    fi
    IFS=":"
    treespan=`echo "${nctree[*]}"`
  fi 
  echo -n "Enter Filename(s) [eg. test.txt or *.txt] : "
  read file

	ls -1 $file 2> /dev/null |wc -l |while read test; do
	echo ""
	echo ""	
	echo -e "\t\t$test matching files found "
	done
	echo ""
  	echo ""
  	echo ""
  ask flag 24 "Commit data? (Y/N) [N]: " n
done

cat <<JOBQVARS > ~/.jobqvars
file=$file
queue=$queue
nodes=$nodes
processors=$processors
walltime=$walltime
lmodules=$lmodules
command=$command
JOBQVARS

cat <<JOBQHEAD > ~/.jobqhead
#!/bin/bash
#PBS -q $queue
#PBS -l walltime=$walltime:00:00
#PBS -l nodes=$nodes:ppn=$processors
cd \$PBS_O_WORKDIR
starts=\$(date +"%s")
start=\$(date +"%r, %m-%d-%Y")
JOBQHEAD
if [ "$lmodules" = "y" -o "$lmodules" = "Y" ]; then
echo "module use /apps/group/bioinformatics/modules" >> ~/.jobqhead
for ((i=0; i<$nctrees; i++))
      do
echo module load ${nctree[i]} >> ~/.jobqhead
      done
fi
for input in $file; do
output=`echo "$input"|sed 's/\..\+$//g'`
cat ~/.jobqhead > $output.sub
sed -i "4a \
#PBS -N $output" $output.sub
if [ "$1" == "" ]; then
cat <<CODE >> $output.sub
Your command for each file here $f 
CODE
else
cat $1 | sed -e "s/\$input/`eval "echo '\$input'"`/g" | sed -e "s/\$output/`eval "echo '\$output'"`/g" >> $output.sub
(cat <<- TIMEC
	ends=\$(date +"%s")
	end=\$(date +"%r, %m-%d-%Y")
	diff=\$((\$ends-\$starts))
	hours=\$((\$diff / 3600))
	dif=\$((\$diff % 3600))
	minutes=\$((\$dif / 60))
	seconds=\$((\$dif % 60))
	echo ""
	printf "\t===========Time Stamp===========\n"
	printf "\tStart\t:\$start\n\tEnd\t:\$end\n\tTime\t:%02d:%02d:%02d\n" "\$hours" "\$minutes" "\$seconds"
	printf "\t================================\n"
	echo ""
	TIMEC
) >> $output.sub
fi
JOBN=("${JOBN[@]}" "$output.sub")
done
ask ready 24 "Submission files ready, submit now? (Y/N) [N] : " n
if [ "$ready" = "y" -o "$ready" = "Y" ]; then
for var in "${JOBN[@]}"
do
  qsub "${var}"
done
fi

