package main

import (
	"errors"
	"fmt"
	"github.com/Masterminds/sprig"
	"github.com/gin-contrib/cors"
	"github.com/gin-contrib/gzip"
	"github.com/gin-gonic/gin"
	auth "github.com/jackdoe/gin-basic-auth-dynamic"
	. "github.com/jackdoe/txt.black/common"
	"github.com/jackdoe/txt.black/db"
	. "github.com/jackdoe/txt.black/model"
	"io/ioutil"
	"net/http"
	"strings"
	"time"
)

const MIN_PASS_LEN = 4

type ChangePasswordInput struct {
	NewPassword string `form:"new_password" json:"new_password" binding:"required"`
}

type BlogInput struct {
	Title string   `form:"title" json:"title" binding:"required"`
	Text  string   `form:"text" json:"text" binding:"required"`
	Tags  []string `form:"tags[]" json:"tags"`
	Slug  string   `form:"slug" json:"slug" binding:"required"`
}

type DeleteInput struct {
	Slug string `form:"slug" json:"slug" binding:"required"`
}

func standardizeSpaces(s string) string {
	return strings.Join(strings.Fields(s), "-")
}

func sanitize(s string) string {
	return standardizeSpaces(strings.ToLower(s))
}

func main() {
	db.Setup()

	r := gin.Default()
	fm := sprig.FuncMap()
	InjectFuncMap(fm)
	r.SetFuncMap(fm)
	r.Use(gzip.Gzip(gzip.DefaultCompression))

	db := db.DB()
	r.Use(gin.Recovery())
	r.Use(cors.Default())
	r.Static("/assets", "./assets")
	r.LoadHTMLGlob("./t/*.tmpl")

	r.GET("/", func(c *gin.Context) {
		var blogs []*Blog
		db.Preload("User").Preload("Tags").Order("id desc").Limit(100).Find(&blogs)
		c.HTML(http.StatusOK, "index.tmpl", map[string]interface{}{
			"Blogs": blogs,
		})
	})

	findBlog := func(c *gin.Context) {
		slug := c.Param("slug")
		var user User
		db.Find(&user, "user_name = ?", c.Param("user"))
		if user.ID == 0 {
			c.String(http.StatusNotFound, "user not found")
		}

		var blogs []*Blog
		matching := []*Blog{}
		notMatching := []*Blog{}
		db.Preload("User").Preload("Tags").Order("id desc").Where("user_id = ?", user.ID).Find(&blogs)
		title := user.UserName

		if len(slug) > 0 {
			for _, b := range blogs {
				found := false
				if b.Slug == slug {
					matching = append(matching, b)
					title = b.Title
					found = true
				} else {
				TAG:
					for _, tag := range b.Tags {
						if tag.Tag == slug {
							matching = append(matching, b)
							found = true
							break TAG
						}
					}
				}
				if !found {
					notMatching = append(notMatching, b)
				}
			}
			if len(matching) == 0 {
				c.String(http.StatusNotFound, "no blog posts found matching the request")
			}
		} else {
			notMatching = blogs
		}

		c.HTML(http.StatusOK, "user.tmpl", map[string]interface{}{
			"NotMatching": notMatching,
			"Matching":    matching,
			"Title":       title,
		})
	}

	r.GET("/~:user/:slug", findBlog)
	r.GET("/~:user", findBlog)

	authorized := r.Group("/v1", auth.BasicAuth(func(c *gin.Context, realm, userName, password string) auth.AuthResult {
		if len(userName) == 0 {
			return auth.AuthResult{Success: false, Text: "need user and password, if the user does not exist it will be created on the fly"}
		}

		if len(password) < MIN_PASS_LEN {
			return auth.AuthResult{Success: false, Text: fmt.Sprintf("password needs to be at least %d characters", MIN_PASS_LEN)}
		}

		userName = sanitize(userName)
		badName := "root" == userName || "user" == userName || "admin" == userName || "webmaster" == userName || "administrator" == userName || len(userName) < 3
		if badName {
			return auth.AuthResult{Success: false, Text: "this username is not allowed"}
		}

		var user User
		db.Find(&user, "user_name = ?", userName)
		if user.ID == 0 {
			user = User{UserName: userName, Password: HashAndSalt([]byte(password))}
			db.Create(&user)
			if user.ID > 0 {
				c.Set("user", &user)
				return auth.AuthResult{Success: true}
			}
			return auth.AuthResult{Success: false, Text: "Wrong username or password, if you are creating new user, then this use alrady exists, please pick another one"}
		}
		if ComparePasswords(user.Password, []byte(password)) {
			c.Set("user", &user)
			return auth.AuthResult{Success: true}
		} else {
			return auth.AuthResult{Success: false, Text: "Wrong username or password, if you are creating new user, then this use alrady exists, please pick another one"}
		}
		return auth.AuthResult{Success: false, Text: "Please specify username and password"}
	}))

	create := func(user *User, input *BlogInput) (*Blog, error) {
		if len(input.Title) == 0 || len(input.Slug) == 0 || len(input.Text) == 0 {
			return nil, errors.New("bad parameters, check out https://txt.black for more info")
		}

		var blog Blog
		db.Preload("Tags").Find(&blog, "user_id = ? AND slug = ?", user.ID, input.Slug)

		blog.Data = input.Text
		blog.Slug = sanitize(input.Slug)
		blog.Title = input.Title
		blog.UserID = user.ID

		if blog.ID != 0 {
			blog.UpdatedAt = time.Now()
			db.Save(&blog)
		} else {
			blog.CreatedAt = time.Now()
			blog.UpdatedAt = time.Now()
			db.Create(&blog)
		}

		db.Where("blog_id = ?", blog.ID).Delete(Tag{})

		for _, tag := range input.Tags {
			if len(tag) > 0 {
				var tag = Tag{BlogID: blog.ID, Tag: sanitize(tag), CreatedAt: time.Now()}
				db.Create(&tag)
			}
		}
		return &blog, nil
	}

	createFromInput := func(c *gin.Context) {
		user := c.MustGet("user").(*User)
		text, err := ioutil.ReadAll(c.Request.Body)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err})
			return
		}

		if len(text) > 1*1024*1024 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Max 1mb"})
			return
		}

		blog, err := create(user, &BlogInput{
			Title: c.Param("title"),
			Slug:  c.Param("slug"),
			Text:  string(text),
			Tags:  strings.Split(c.Param("tags"), ","),
		})

		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err})
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true, "blog.id": blog.ID, "slug": blog.Slug})
	}

	authorized.POST("/post/:slug/:title/:tags", createFromInput)
	authorized.POST("/post/:slug/:title", createFromInput)
	authorized.POST("/postForm", func(c *gin.Context) {
		var json BlogInput
		if err := c.ShouldBind(&json); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		user := c.MustGet("user").(*User)
		blog, err := create(user, &json)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err})
			return
		}
		c.Redirect(http.StatusFound, fmt.Sprintf("/~%s/%s", user.UserName, blog.Slug))
	})

	authorized.POST("/api/post", func(c *gin.Context) {
		var json BlogInput
		if err := c.ShouldBindJSON(&json); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		user := c.MustGet("user").(*User)
		blog, err := create(user, &json)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err})
			return
		}
		c.JSON(http.StatusOK, gin.H{"success": true, "blog.id": blog.ID, "slug": blog.Slug})
	})

	formWithOrWithotSlug := func(c *gin.Context) {
		var blog Blog
		user := c.MustGet("user").(*User)
		if user.ID != 0 {
			var blogs []Blog
			db.Preload("User").Preload("Tags").Order("id desc").Where("user_id = ? AND slug=?", user.ID, c.Param("slug")).Find(&blogs)
			if len(blogs) > 0 {
				blog = blogs[0]
			}
		}
		blog.Slug = sanitize(c.Param("slug"))

		c.HTML(http.StatusOK, "edit.tmpl", map[string]interface{}{
			"Blog": blog,
			"User": user,
		})
	}

	authorized.GET("/form/:slug", formWithOrWithotSlug)
	authorized.GET("/form", formWithOrWithotSlug)

	authorized.POST("/api/changePassword", func(c *gin.Context) {
		var json ChangePasswordInput
		if err := c.ShouldBindJSON(&json); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if len(json.NewPassword) < MIN_PASS_LEN {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("password has to be at least %d characters", MIN_PASS_LEN)})
			return

		}
		user := c.MustGet("user").(*User)
		user.Password = HashAndSalt([]byte(json.NewPassword))
		db.Save(&user)
		c.JSON(http.StatusOK, gin.H{"success": true})
	})

	deleteFunc := func(user *User, input *DeleteInput) bool {
		var blog Blog
		db.Find(&blog, "user_id = ? AND slug = ?", user.ID, input.Slug)
		if blog.ID == 0 {
			return false
		} else {
			db.Delete(&blog)
			return true
		}
	}

	authorized.POST("/delete/:slug", func(c *gin.Context) {
		user := c.MustGet("user").(*User)
		c.JSON(http.StatusOK, gin.H{"success": deleteFunc(user, &DeleteInput{Slug: c.Param("slug")})})
	})

	authorized.POST("/api/delete", func(c *gin.Context) {
		var json DeleteInput
		if err := c.ShouldBindJSON(&json); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		user := c.MustGet("user").(*User)
		c.JSON(http.StatusOK, gin.H{"success": deleteFunc(user, &json)})
	})

	r.Run()
}
