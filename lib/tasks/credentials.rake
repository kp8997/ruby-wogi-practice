# frozen_string_literal: true

namespace :credentials do
  desc "Generate a brand new config/master.key and matching credentials.yml.enc for local development"
  task :generate_key do
    key_path = Rails.root.join("config", "master.key")
    cred_path = Rails.root.join("config", "credentials.yml.enc")

    if File.exist?(key_path) && ENV["FORCE"] != "1"
      puts "config/master.key already exists! Pass FORCE=1 to overwrite."
      next
    end

    FileUtils.rm_f(cred_path)
    FileUtils.rm_f(key_path)

    system({ "EDITOR" => "true" }, "bin/rails", "credentials:edit")

    if File.exist?(key_path)
      puts "\nSuccessfully generated a new local config/master.key:"
      puts File.read(key_path).strip
      puts "\nMatching config/credentials.yml.enc has been initialized."
    else
      puts "\nFailed to generate master.key. Please try running: rm -f config/credentials.yml.enc && EDITOR=\"true\" bin/rails credentials:edit"
    end
  end
end
