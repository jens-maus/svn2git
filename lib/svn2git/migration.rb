module Svn2Git
  class Migration
  
    attr_reader :dir
    
    def initialize(url, options = {})
      @url = url
      @dir = @url.scan(/[^\/]+/).last
      
      @options = options
      @options[:trunk] ||= 'trunk'
      @options[:branches] ||= 'branches'
      @options[:tags] ||= 'tags'
      
      @authors = options[:authors]
    end
    
    def run!
      clone!
      fix_tags
      fix_branches
      fix_trunk
    end
    
  private
    
    def clone!
      trunk = @options[:trunk]
      branches = @options[:branches]
      tags = @options[:tags]
      run_command("git svn init --no-metadata --trunk=#{trunk} --branches=#{branches} --tags=#{tags} #{@url}")
      run_command("git config svn.authorsfile #{@authors}") if @authors
      run_command("git svn fetch")
      get_branches
    end
    
    def get_branches
      @branches = `git branch -a`.split(/\n/)
      @local = `git branch`.split(/\n/)
      @remote = @branches.find_all { |b| not @local.include?(b) }
      @tags = @remote.find_all { |b| b.strip =~ %r{^#{@options[:tags]}\/} }
    end
    
    def fix_tags
      @tags.each do |tag|
        id = tag.strip.gsub(%r{^#{@options[:tags]}\/}, '')
        run_command("git checkout #{tag}")
        run_command("git tag -a -m 'Tagging release #{id}' #{id}")
      end
    end
    
    def fix_branches
      svn_branches = @remote.find_all { |b| not @tags.include?(b) }
      svn_branches.each do |branch|
        branch = branch.strip
        next if branch == @options[:trunk]
        run_command("git checkout #{branch}")
        run_command("git checkout -b #{branch}")
      end
    end
    
    def fix_trunk
      trunk = @remote.find { |b| b.strip == @options[:trunk] }
      if trunk
        run_command("git checkout trunk")
        run_command("git branch -D master")
        run_command("git checkout -f -b master")
      end
    end
    
    def run_command(cmd)
      IO.popen(cmd) do |stdout|
        stdout.each do |line|
          puts line if @options[:verbose]
        end
      end
    end
  
  end
end
