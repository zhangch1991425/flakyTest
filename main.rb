require 'git'
require 'csv'
require 'fileutils'
require 'travis'
require 'open4'
require 'date'
@@number_of_repositories=5
def create_repository()
  File.open('/home/zc/projects/wechat_jump_game/create.sh','w') do |file|
    file.puts 'cd /home/zc/projects/wechat_jump_game'
    file.puts 'pwd'
    file.puts '#!/bin/bash'
    file.puts 'hub create jump1'
    #file.puts '#!/usr/bin/expect'
    #file.puts 'spawn hub create jump1'
    #file.puts 'expect "Enter username:"'
    #file.puts 'send "340355960@qq.com\r"'
    #file.puts 'expect "Enter password:"'
    #file.puts 'send "cumtzc04091751\r"'
    #file.puts 'expect eof'
  end
  %x"chmod 777 /home/zc/projects/wechat_jump_game/create.sh"
  #%x"/home/zc/projects/checkstyle/checkstyle/create.sh"
  `/home/zc/projects/wechat_jump_game/create.sh`
  puts __FILE__
end
def tracis_enable()
  File.open('/home/zc/projects/wechat_jump_game/travis.sh','w') do |file|
    file.puts '#!/bin/bash'
    file.puts 'cd /home/zc/projects/wechat_jump_game'
    file.puts 'travis enable -r zhangch1991425/jump1'
    file.puts 'git remote add jump1 git@github.com:zhangch1991425/jump1.git'
  end
  %x"chmod 777 /home/zc/projects/wechat_jump_game/travis.sh"
  `/home/zc/projects/wechat_jump_game/travis.sh`
end

def clone_repo(user_dir,repo_url,repo_dir)
  i=0
  while(i<600)
    FileUtils.rm_rf(repo_dir) if File.exist?(repo_dir)
    result=%x"cd #{user_dir} && git clone #{repo_url}"
    if $?.to_i!=0
      i+=1
      sleep 60
      next
    else
      break
    end
  end
end

def create_github_repo(repo_dir,user_name,repo_name,i)
  k=0
  while(i<600)
    %x"cd #{repo_dir} && hub create #{user_name}_#{repo_name}_#{i}"
    if $?.to_i!=0
      k+=1
      sleep 60
      next
    else
      puts "Create repo zhangch1991425/#{user_name}_#{repo_name}_#{i} on Github"
      break
    end
  end
end

def open_travis(repo_dir,user_name,repo_name,i)
  k=0
  while(k<600)
    %x"cd #{repo_dir} && travis enable -r zhangch1991425/#{user_name}_#{repo_name}_#{i}"
    if $?.to_i!=0
      k+=1
      sleep 60
      next
    else
      puts "Enable travis zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      break
    end
  end
end

def link_remote(repo_dir,user_name,repo_name,i)
  k=0
  while(k<600)
    %x"cd #{repo_dir} && git remote add #{user_name}_#{repo_name}_#{i} git@github.com:zhangch1991425/#{user_name}_#{repo_name}_#{i}.git"
    if $?.to_i!=0
      k+=1
      sleep 60
      next
    else
      puts "Link to Github repo zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      break
    end
  end
end

def enable_travis(repo_dir,user_name,repo_name)
  (0...@@number_of_repositories).each do |i|
    create_github_repo(repo_dir,user_name,repo_name,i)
    sleep 60
    open_travis(repo_dir,user_name,repo_name,i)
    link_remote(repo_dir,user_name,repo_name,i)
  end
end

def pre_build_completed(user_name,repo_name,i)
  sleep 300
  i=0
  begin
    travis_repo=Travis::Repository.find("zhangch1991425/#{user_name}_#{repo_name}_#{i}")
  rescue
    travis_repo=nil
    sleep 60
    i+=1
    retry if i<100
  end
  return unless travis_repo
  last=travis_repo.last_build
  return unless last
  while(last.running?)
    sleep 300
  end
end

def push(repo_dir,user_name,repo_name,l,i)
  k=0
  while(k<5)
    %x"cd #{repo_dir} && git push #{user_name}_#{repo_name}_#{i} #{l.sha}:refs/heads/master"
    if $?.to_i==0
      puts "===Push #{l.sha}  #{l.date} to Github repo zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      break
    elsif $?.to_i==256
      puts "===Push Error $?=#{$?.to_i} #{l.sha}  #{l.date} to Github repo zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      puts "===hint: Updates were rejected because the tip of your current branch is behind"
      break
    elsif $?.to_i==32768
      puts "===Push Error $?=#{$?.to_i} #{l.sha}  #{l.date} to Github repo zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      puts "===ERROR: Repository not found"
      k+=1
      sleep 60
      next
    else
      puts "===Push Error $?=#{$?.to_i} #{l.sha}  #{l.date} to Github repo zhangch1991425/#{user_name}_#{repo_name}_#{i}"
      k+=1
      sleep 60
      next
    end
  end
end

def git_push(repo_dir,user_name,repo_name,first_commit_time)
  days=(Time.now.to_date-first_commit_time.getlocal.to_date).to_i
  g=Git.open(repo_dir)
  g_log=g.log(nil).since("#{days} days ago")
  g_log.reverse_each do |l|
    (0...@@number_of_repositories).each do |i|
      push(repo_dir,user_name,repo_name,l,i)
    end
    (0...@@number_of_repositories).each do |i|
      pre_build_completed(user_name,repo_name,i)
    end
  end
end

def create_dir(user_name,repo_name,repo_url,first_commit_time)
  user_dir=File.join('repositories',user_name)
  repo_dir=File.join('repositories',user_name,repo_name)
  return if File.exist?(repo_dir)
  FileUtils.mkdir_p(user_dir) unless File.exist?(user_dir)
  clone_repo(user_dir,repo_url,repo_dir)
  enable_travis(repo_dir,user_name,repo_name)
  git_push(repo_dir,user_name,repo_name,first_commit_time)
end

def use_travis(user_name,repo_name,repo_url)
  i=0
  begin
    travis_repo=Travis::Repository.find("#{user_name}/#{repo_name}")
  rescue Exception=>e
    travis_repo=nil
    puts e
    puts "#{user_name},#{repo_name}"
    sleep 60
    i+=1
    retry if i<10
  end
  if travis_repo && travis_repo.last_build && travis_repo.last_build.number.to_i>10
    first_commit_time=travis_repo.build(1).commit.committed_at
    create_dir(user_name,repo_name,repo_url,first_commit_time)
  end
end

def csv_traverse(csv_file)
  CSV.foreach(csv_file,headers:true,col_sep:',') do |row|
    use_travis(row[0],row[1],row[2])
  end
  puts '========================END============================='
end
csv_traverse(ARGV[0])
#csv_traverse('java_github_repo.csv')

