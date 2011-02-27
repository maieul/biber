#!/bin/bash

# uploadsf.sh <dir> <release>

# where <dir> is where these are:
# biber-MSWIN.exe
# biber-darwin_x86_64
# biber-linux_x86_32
# biber-linux_x86_64

# and <release> is a subdir of /home/frs/project/b/bi/biblatex-biber/biblatex-biber/
# on SF

BASE="/Users/philkime/data/code/biblatex-biber"
DOCDIR=$BASE/doc
DRIVERDIR=$BASE/lib/Biber/Input/
BINDIR=$BASE/dist
XSLDIR=$BASE/data
DIR=${1:-"/Users/philkime/Desktop/b"}
RELEASE=${2:-"development"}
export COPYFILE_DISABLE=true # no resource forks - TL doesn't like them

# Make binary dir if it doesn't exist
if [ ! -e $DIR ]; then
  mkdir $DIR
fi

# Create the binaries from the build farm if they don't exist
# Local OSX
if [ ! -e $DIR/biber-darwin_x86_64 ]; then
  (cd $BASE;perl ./Build.PL;sudo ./Build install;cd dist/darwin_x86_64;./build.sh)
  cp $BASE/dist/darwin_x86_64/biber-darwin_x86_64 $DIR/
fi

# Build farm WinXP
if [ ! -e $DIR/biber-MSWIN.exe ]; then
  ssh root@wood "VBoxHeadless --startvm bbf-wxp32 </dev/null >/dev/null 2>&1 &"
  sleep 5
  ssh bbf-wxp32 "cd biblatex-biber;git pull;perl ./Build.PL;./Build install;cd dist/MSWin32;./build.bat"
  scp bbf-wxp32:biblatex-biber/dist/MSWin32/biber-MSWIN.exe $DIR/
  ssh root@wood "VBoxManage controlvm bbf-wxp32 savestate"
fi

# Build farm Linux 32
if [ ! -e $DIR/biber-linux_x86_32 ]; then
  ssh root@wood "VBoxHeadless --startvm bbf-jj32 </dev/null >/dev/null 2>&1 &"
  sleep 5
  ssh bbf-jj32 "cd biblatex-biber;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build install;cd dist/linux_x86_32;./build.sh"
  scp bbf-jj32:biblatex-biber/dist/linux_x86_32/biber-linux_x86_32 $DIR/
  ssh root@wood "VBoxManage controlvm bbf-jj32 savestate"
fi

# Build farm Linux 64
if [ ! -e $DIR/biber-linux_x86_64 ]; then
  ssh root@wood "VBoxHeadless --startvm bbf-jj64 </dev/null >/dev/null 2>&1 &"
  sleep 5
  ssh bbf-jj64 "cd biblatex-biber;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build install;cd dist/linux_x86_64;./build.sh"
  scp bbf-jj64:biblatex-biber/dist/linux_x86_64/biber-linux_x86_64 $DIR/
  ssh root@wood "VBoxManage controlvm bbf-jj64 savestate"
fi

cd $DIR
# Windows
cp biber-MSWIN.exe biber.exe
chmod +x biber.exe
/usr/bin/zip biber.zip biber.exe
scp biber.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber.zip
\rm biber.zip biber.exe
# OSX
cp biber-darwin_x86_64 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber.tar.gz
\rm biber.tar.gz biber
# Linux 32-bit
cp biber-linux_x86_32 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_32bit/biber.tar.gz
\rm biber.tar.gz biber
# Linux 64-bit
cp biber-linux_x86_64 biber
chmod +x biber
tar cf biber.tar biber
gzip biber.tar
scp biber.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux_64bit/biber.tar.gz
\rm biber.tar.gz biber
# Doc
scp $DOCDIR/biber.pdf philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/documentation/biber.pdf
# Changes file
scp $BASE/Changes philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/Changes
# Driver control file docs
find $DRIVERDIR -name \*.dcf | xargs -I{} cp {} ~/Desktop/
for dcf in ~/Desktop/*.dcf
do
$BINDIR/make-pretty-dcfs.pl $dcf $XSLDIR/dcf.xsl
scp $dcf.html philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/documentation/drivers/
\rm -f $dcf $dcf.html
done

if [ $RELEASE != "development" ]; then
# Perl dist tree
scp $BASE/biblatex-biber-*.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/b/bi/biblatex-biber/biblatex-biber/$RELEASE/biblatex-biber.tar.gz
rm $BASE/biblatex-biber-*.tar.gz
# Make TLContrib main package (docs only)
mkdir -p ~/Desktop/doc/biber
cp $DOCDIR/biber.pdf ~/Desktop/doc/biber/
\rm -f ~/Desktop/doc/.DS_Store
\rm -f ~/Desktop/doc/biber/.DS_Store
tar cvf ~/Desktop/biber.tar -C ~/Desktop doc
gzip ~/Desktop/biber.tar
\rm -rf ~/Desktop/doc
fi
