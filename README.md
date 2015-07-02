drag-and-drop-js-ruby
=====================
This drag and drop uploader with core javascript and ruby on rails on server, with ajax queue to support mass upload

HOW TO USE:
This project has code snippet which you can use in any ruby on rails projects. Go to code folder, here is the description of every file and how you can use them in your application.

route.rb : contain route where this uploader send the file

uploads_controller.rb : contain controller action which above url hit to upload file.

uploaed_file.rb : contain actual method to upload file on disk or s3. Assuming this will be model for to keep metadata on db.

util.rb : contain some utility methods

_uploader.html.erb : This partial contains code to generate drag and drop uploader on any page it.

usage.rb : sample call to uploader partial