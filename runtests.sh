#!/bin/bash

if [[ "$1" == "profile" ]] ; then
    echo "profiling code"
    perl -d:NYTProf  ./tests/test.pl
    rm -rf nytprof.old || echo "no old to remove"
    mv nytprof nytprof.old
    nytprofhtml --open

elif [[ "$1" == "full" ]]  ;then
    echo "full test, coverage and profiling"

    perl -d:NYTProf  ./tests/test.pl  && \
    perl -MDevel::Cover=+select,^lib/.*\.pm,+select,modules/.*\.pm,+ignore,^/,tests/  ./tests/test.pl >/dev/null && \
    cover -summary && \
    chmod -R 755 cover_db && \
    rm -rf nytprof.old || echo "no old to remove"
    mv nytprof nytprof.old
    nytprofhtml --open

elif [[ "$1" == "cover" ]] ;then
    echo " checking code coverage"

    perl -MDevel::Cover=+select,^lib/.*\.pm,+select,modules/.*\.pm,+ignore,^/,tests/  ./tests/test.pl >/dev/null && \
    cover -summary && \
    chmod -R 755 cover_db

else
    echo "quick test"
    perl ./tests/test.pl


fi
