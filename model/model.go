package model

import (
	"time"
)

type User struct {
	ID        uint      `gorm:"primary_key"`
	CreatedAt time.Time `json:"-"`
	UpdatedAt time.Time `json:"-"`

	UserName string `gorm:"type:varchar(255)"`
	Password string `json:"-"`
	Blogs    []Blog `json:"-"`
}

type Blog struct {
	ID            uint `gorm:"primary_key"`
	CreatedAt     time.Time
	UpdatedAt     time.Time
	UserID        uint
	User          User `json:"-"`
	Tags          []Tag
	AllowComments bool
	Slug          string `gorm:"type:varchar(255)"`
	Title         string `gorm:"type:longtext"`
	Data          string `gorm:"type:longtext"`
}

type Tag struct {
	ID        uint      `gorm:"primary_key"`
	CreatedAt time.Time `json:"-"`
	BlogID    uint      `json:"-"`
	Tag       string    `gorm:"type:varchar(255)"`
}
