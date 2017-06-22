mvn -N io.takari:maven:wrapper
mvn install > out.txt
grep -nv "DEBUG org.springframework" out.txt
