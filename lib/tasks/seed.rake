# lib/tasks/seed.rake
namespace :db do
  namespace :seed do
    desc "Seed the database with Foundation Foods dataset"
    task foundation: :environment do
      ENV["DATASET"] = "foundation"
      Rake::Task["db:seed"].invoke
    end

    desc "Seed the database with FNDDS dataset"
    task fndds: :environment do
      ENV["DATASET"] = "fndds"
      Rake::Task["db:seed"].invoke
    end

    desc "Reset database and seed with Foundation Foods dataset"
    task reset_foundation: :environment do
      Rake::Task["db:reset"].invoke
      ENV["DATASET"] = "foundation"
      Rake::Task["db:seed"].invoke
    end

    desc "Reset database and seed with FNDDS dataset"
    task reset_fndds: :environment do
      Rake::Task["db:reset"].invoke
      ENV["DATASET"] = "fndds"
      Rake::Task["db:seed"].invoke
    end
  end
end
