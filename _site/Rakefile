desc "compile and run the site"
task :default do
  system "jekyll server"
end

desc "create a new post"
task :post do
  today = Time.now.strftime('%Y-%m-%d')
  title = ENV['title'].downcase.gsub(" ", "_").gsub(/[^0-9A-Za-z_]/, '').strip
  title = "#{today}-#{title}.md"
  file = File.join("./_posts", title)

  File.open(file, "w") do |post|
    post.puts "---"
    post.puts "layout: post"
    post.puts "title: #{ENV['title']}"
    post.puts "---"
    post.puts ""
    post.puts "Write your post here"
  end
end
