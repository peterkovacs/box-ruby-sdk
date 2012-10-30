$: << File.dirname(__FILE__) # for 1.9

# log in using the login example, so we don't have to duplicate code
require 'login'

# use a temporary file to upload
require 'tempfile'

# get the root of the folder structure
root = @account.root

puts "Enter the name of the file to save:"
file_name = gets.chomp

puts "Enter one line for the content of the file:"
content = gets

temp = Tempfile.new(file_name)
File.open(temp.path, 'w') do |file|
  file.write(content)
end

# uploads the file with the ugly temporary name
result = root.upload_file(temp)

# rename the file to make it look better
result = result.update(:name => file_name)
puts "Done! #{ result.name } written to Box"

temp.unlink
