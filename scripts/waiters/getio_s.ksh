#!/bin/ksh

#################################
# This scripts produces an ops/sec
# output for mmpmon io_s and
# fs_io_s output
#
# It will continue until killed
#
# - jessig 03/17/10
# added an until loop so it would 
# write out to a logfile
# also changed time stamp from 
# systime to something that matches
# the time from the waiters script
################################


#########################
# Function: process_io_s
#  Process -p output into 
# columns with rate/sec values
#################################

process_io_s () {
echo io_s | /usr/lpp/mmfs/bin/mmpmon -s -r 0 -d $1 -p | awk 'BEGIN\
{\
  count=0;\
  prior_t=0;\
  prior_tu=0;\
  prior_br=0;\
  prior_bw=0;\
  prior_fo=0;\
  prior_fc=0;\
  prior_rdio=0;\
  prior_wrio=0;\
  prior_rdir=0;\
  prior_inup=0;\
  printf("Timestamp\tReadMB/s  WriteMB/s\tF_open\tf_close\treads\twrites\trdir\tinode\n");\
}\
{\
  count++;\
  t = $9;\
  tu = $11;\
  br = $13;\
  bw = $15;\
  fo = $17;\
  fc = $19;\
  rdio = $21;\
  wrio = $23;\
  rdir = $25;\
  inup = $27;\
\
  if(count > 1)\
  {\
    delta_t = t-prior_t;\
    delta_tu = tu-prior_tu;\
    delta_br = br-prior_br;\
    delta_bw = bw-prior_bw;\
    delta_fo = fo-prior_fo;\
    delta_fc = fc-prior_fc;\
    delta_rdio = rdio-prior_rdio;\
    delta_wrio = wrio-prior_wrio;\
    delta_rdir = rdir-prior_rdir;\
    delta_inup = inup-prior_inup;\
\
    dt = delta_t + (delta_tu / 1000000.0);\
    if(dt > 0) {\
      rrate = (delta_br / dt) / 1000000.0;\
      wrate = (delta_bw / dt) / 1000000.0;\
      forate = (delta_fo / dt) ;\
      fcrate = (delta_fc / dt) ;\
      rdiorate = (delta_rdio / dt) ;\
      wriorate = (delta_wrio / dt) ;\
      rdirrate = (delta_rdir / dt) ;\
      inuprate = (delta_inup / dt) ;\
      printf("%d\t%5.1f\t%5.1f\t\t%d\t%d\t%d\t%d\t%d\t%d\n",\
             systime(),rrate,wrate,forate,fcrate,rdiorate,wriorate,rdirrate,inuprate);\
    }\
  }\
  prior_t=t;\
  prior_tu=tu;\
  prior_br=br;\
  prior_bw=bw;\
  prior_fo=fo;\
  prior_fc=fc;\
  prior_rdio=rdio;\
  prior_wrio=wrio;\
  prior_rdir=rdir;\
  prior_inup=inup;\
}'

}


process_fs_io_s () {
# Get the number of file systems to be monitored
numfsin=`/usr/lpp/mmfs/bin/mmlsfs all | grep 'File system attributes' | wc -l`;

until [[ $now = "the end of time" ]];do
echo fs_io_s | /usr/lpp/mmfs/bin/mmpmon -s -r 5 -d $1 -p | awk 'BEGIN\
{\
  numfs="'$numfsin'";\
  fscount=0;\
\
  count=0;\
  for (i=0;i<numfs;i++) { \
    prior_t[i]=0;\
    prior_tu[i]=0;\
    prior_br[i]=0;\
    prior_bw[i]=0;\
    prior_fo[i]=0;\
    prior_fc[i]=0;\
    prior_rdio[i]=0;\
    prior_wrio[i]=0;\
    prior_rdir[i]=0;\
    prior_inup[i]=0;\
  }\
  printf("Timestamp\tFsname ReadMB/s  WriteMB/s\tF_open\tf_close\treads\twrites\trdir\tinode\n");\
}\
{\

  fscount++;\
  if(fscount >= numfs) { fscount=0 } \
  count++;\
  t[fscount] = $9;\
  tu[fscount] = $11;\
  fs[fscount] = $15;\
  br[fscount] = $19;\
  bw[fscount] = $21;\
  fo[fscount] = $23;\
  fc[fscount] = $25;\
  rdio[fscount] = $27;\
  wrio[fscount] = $29;\
  rdir[fscount] = $31;\
  inup[fscount] = $33;\
\
  if(count > 1)\
  {\
    delta_t[fscount] = t[fscount]-prior_t[fscount];\
    delta_tu[fscount] = tu[fscount]-prior_tu[fscount];\
    delta_br[fscount] = br[fscount]-prior_br[fscount];\
    delta_bw[fscount] = bw[fscount]-prior_bw[fscount];\
    delta_fo[fscount] = fo[fscount]-prior_fo[fscount];\
    delta_fc[fscount] = fc[fscount]-prior_fc[fscount];\
    delta_rdio[fscount] = rdio[fscount]-prior_rdio[fscount];\
    delta_wrio[fscount] = wrio[fscount]-prior_wrio[fscount];\
    delta_rdir[fscount] = rdir[fscount]-prior_rdir[fscount];\
    delta_inup[fscount] = inup[fscount]-prior_inup[fscount];\

    if(t[fscount]!=t[fscount]-prior_t[fscount]) {\
      dt = delta_t[fscount] + (delta_tu[fscount] / 1000000.0)}\


    if(dt > 0) {\
      rrate[fscount] = (delta_br[fscount] / dt) / 1000000.0;\
      wrate[fscount] = (delta_bw[fscount] / dt) / 1000000.0;\
      forate[fscount] = (delta_fo[fscount] / dt) ;\
      fcrate[fscount] = (delta_fc[fscount] / dt) ;\
      rdiorate[fscount] = (delta_rdio[fscount] / dt) ;\
      wriorate[fscount] = (delta_wrio[fscount] / dt) ;\
      rdirrate[fscount] = (delta_rdir[fscount] / dt) ;\
      inuprate[fscount] = (delta_inup[fscount] / dt) ;\
      #printf("%d\t%s\t%5.1f\t%5.1f\t\t%d\t%d\t%d\t%d\t%d\t%d\n",\
      printf("%s\t%s\t%5.1f\t%5.1f\t\t%d\t%d\t%d\t%d\t%d\t%d\n",\
             #systime(),fs[fscount],rrate[fscount],wrate[fscount],forate[fscount],\
             strftime("%a %b %d %T %Z %Y"),fs[fscount],rrate[fscount],wrate[fscount],forate[fscount],\
             fcrate[fscount],rdiorate[fscount],wriorate[fscount],\
             rdirrate[fscount],inuprate[fscount]);\
    }\
  }\
  prior_t[fscount]=t[fscount];\
  prior_tu[fscount]=tu[fscount];\
  prior_br[fscount]=br[fscount];\
  prior_bw[fscount]=bw[fscount];\
  prior_fo[fscount]=fo[fscount];\
  prior_fc[fscount]=fc[fscount];\
  prior_rdio[fscount]=rdio[fscount];\
  prior_wrio[fscount]=wrio[fscount];\
  prior_rdir[fscount]=rdir[fscount];\
  prior_inup[fscount]=inup[fscount];\
}'
done
}
# end fs_io_s

# Default to 2 second interval 
((interval=2000))

#########################
# Command line processing
#########################

# See if usage should be displayed
if [[ $1 == '-?' || $1 == '-h' ||
      $1 == '--help' ]]; then
   echo "Usage: $0 [interval in seconds] [io_s|fs_io_s] "
   echo "   io_s is the default mode "
   exit
fi

# See if there is an interval set
if [[ -n $1  && $1 == +([0-9]) ]]; then
  ((interval=${1}*1000))
fi

# Print Parameters for reference purposes
((intervalp=interval/1000))
print Started: `/bin/date`
print Sample Interval: $intervalp Seconds


# check to see if fs_io_s or io_s is specified.
# default to io_s
if [[ $2 == 'fs_io_s' || $1 == 'fs_io_s' ]]; then
  process_fs_io_s $interval
else
  process_io_s $interval
fi

