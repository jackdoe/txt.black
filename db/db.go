package db

import (
	. "github.com/jackdoe/txt.black/common"
	. "github.com/jackdoe/txt.black/model"
	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	"log"
	"os"
)

var db *gorm.DB

func Setup() {
	url := os.Getenv("MYSQL_URL")
	if url == "" {
		log.Fatal("need env MYSQL_URL for example MYSQL_URL=root:asd@/txt?charset=utf8&parseTime=True&loc=Local")
	}
	_db, err := gorm.Open("mysql", url)
	if err != nil {
		log.Fatalf("failed to connect: %v", err)
	}
	db = _db
	db.LogMode(DevMode())
	db.Set("gorm:table_options", "ENGINE=InnoDB").AutoMigrate(
		&User{},
		&Blog{},
		&Tag{},
	)

	db.Model(&User{}).AddUniqueIndex("u_idx_user_name", "user_name")
	db.Model(&Blog{}).AddUniqueIndex("u_uid_slug", "user_id", "slug")
	db.Model(&Tag{}).AddUniqueIndex("t_b_tag", "blog_id", "tag")
}

func DB() *gorm.DB {
	return db
}
