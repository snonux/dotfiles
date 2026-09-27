if test (uname) = Linux
    set -l java_home /usr/lib/jvm/java-latest-openjdk
    if test -d $java_home
        set -gx JAVA_HOME $java_home
    end
end
