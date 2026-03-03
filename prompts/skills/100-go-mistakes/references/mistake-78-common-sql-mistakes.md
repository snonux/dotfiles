# Mistake #78: Common SQL mistakes

* Forgetting that `sql.Open` doesn't necessarily establish connections to a database

Call the `Ping` or `PingContext` method if you need to test your configuration and make sure a database is reachable.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/sql-open)

* Forgetting about connections pooling

Configure the database connection parameters for production-grade applications.

* Not using prepared statements

Using SQL prepared statements makes queries more efficient and more secure.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/prepared-statements)

* Mishandling null values

Deal with nullable columns in tables using pointers or `sql.NullXXX` types.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/null-values/main.go)

* Not handling rows iteration errors

Call the `Err` method of `sql.Rows` after row iterations to ensure that you haven’t missed an error while preparing the next row.

[Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/rows-iterations-errors)
