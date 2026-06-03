if test -d ~/git/gemtexter
    function gemtexter::publish
        cd ~/git/gemtexter
        ./gemtexter --publish
        cd -
    end

    function gemtexter::publish::force
        cd ~/git/gemtexter
        ./gemtexter --publish --force
        cd -
    end
end
