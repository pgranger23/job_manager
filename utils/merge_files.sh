cpwd=$( pwd )
filename='merged.root'
filetype='*.root'
funcname=$FUNCNAME
Help(){
    echo "Usage: $funcname \"filetype\" \"filename\""
    echo "filetype is optional, standard is '*.root'"
    echo "filename is optional, standard is 'merged.root'"
    echo "Execute this function inside the folder with root files"
}

if [ ! -z "$1" ]; then
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        Help
        return 0
    fi
    filetype=$1
fi
if [ ! -z "$2" ]; then
    filename=$2
fi
find $cpwd -name "$filetype" | sed 's#/pnfs/dune/#root://fndca1.fnal.gov:1094/pnfs/fnal.gov/usr/dune/#' > fileshadd.list
semipath=$( pwd | sed 's#/pnfs/dune/#root://fndca1.fnal.gov:1094/pnfs/fnal.gov/usr/dune/#' )
echo "Done creating file"
echo "Executing: "
echo "voms-proxy-init -rfc -noregen -voms=dune:/dune/Role=Analysis -valid 180:00" 
voms-proxy-init -rfc -noregen -voms=dune:/dune/Role=Analysis -valid 180:00
echo "hadd -f $semipath/$filename @fileshadd.list"
hadd -f $semipath/$filename @fileshadd.list
