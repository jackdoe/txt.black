# [txt.black](https://txt.black) - something between irc and facebook

## what is it?

I always wanted to have a place to put some random thoughts, so this is it.

```
$ curl -XPOST --data-binary @blogpost.txt -u user https://txt.black/v1/post/some-permalink-slug/Some%20Title/tag1,tag2

# or
 
$ curl -XPOST -d '{"title":"hi","slug":"yo","tags":["a","b","c"],"text":"asd"}' -u jack https://txt.black/v1/api/post
$ curl -XPOST -d '{"slug":"yo"}' -u jack https://txt.black/v1/api/delete
$ curl -XPOST -d '{"new_password": "whatever password"}' -u jack https://txt.black/v1/api/changePassword

```
## how to run it

create database txtblack
```
MYSQL_URL='root:asd@/txtblack?charset=utf8&parseTime=True&loc=Local' go run main.go 
```

thats pretty much it, it will create the tables and everything (gorm is awesome)

## how to contribute

fork and push :D

## license

MIT

