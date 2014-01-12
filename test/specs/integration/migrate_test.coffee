fs = require('fs')
glob = require('glob')
_ = require('lodash')
sinon = require('sinon')
path = require('path')
assert = require('assert')
mkdirp = require('mkdirp')

MigrationPath = rek('lib/sails-migrations/migration_path.coffee')
DatabaseTasks = rek('lib/sails-migrations/database_tasks.coffee')
Migrator = rek("lib/sails-migrations/migrator.coffee")
SchemaMigration = rek("lib/sails-migrations/schema_migration.coffee")
SailsIntegration = rek("lib/sails-migrations/sails_integration.coffee")
ourAdapter = rek("lib/sails-migrations/adapter.coffee")
migrationsPath = path.resolve('test/example_app/db/migrations')
definitionsPath = path.resolve('test/example_app/db/migrations/definitions')

cleanupMigrationFiles = (migrationsPath, cb)->
  MigrationPath.allMigrationsFiles(migrationsPath, (err, files)->
    _.each(files, fs.unlinkSync.bind(fs))
    cb()
  )

copy = (files, outputPath)->
  _.each(files, (file)->
    outputPath = "#{outputPath}/#{path.basename(file)}"
    fs.writeFileSync(outputPath, fs.readFileSync(file)) #copying
  )

copyFixturesToMigrationsPath = (scope)->
  mkdirp.sync(definitionsPath) #This should create the db/migrations + db/migrations/definitions dirs in the example_app
  console.log 'hi'
  fixturePath = path.resolve('test/specs/fixtures/migrations')
  migrationFixtures = glob.sync("#{fixturePath}/*#{scope}*.js", {})
  definitionFixtures = glob.sync("#{fixturePath}/definitions/*#{scope}*.js", {})
  copy(migrationFixtures, migrationsPath)
  copy(definitionFixtures, definitionsPath)

describe 'db:migrate', ->
  beforeEach (done)->
    modulesPath = path.resolve("test/example_app/node_modules")
    SailsIntegration.loadSailsConfig(modulesPath, (err, config)=>
      @config = config
      @adapter = @config.defaultAdapter
      @ourAdapter = new ourAdapter(@adapter)
      cleanupMigrationFiles(migrationsPath, ->
        done()
      )
    )

  beforeEach (done)->
    DatabaseTasks.drop(@adapter, (err)=>
      DatabaseTasks.create(@adapter, done)
    )

  beforeEach (done)->
    SchemaMigration.getInstance(@adapter, (err, Model)=>
      return done(err) if err
      Model.define(@adapter, done)
    )

  it 'should be able to run a migration', (done)->
    tableName = 'one_migration'
    oneMigrationDefinitionPath = path.resolve("test/specs/fixtures/migrations/definitions/one_migration.js")
    oneMigrationDefinition = require(oneMigrationDefinitionPath)
    copyFixturesToMigrationsPath(tableName)
    Migrator.migrate(@adapter, migrationsPath, null, (err)=>
      return done(err) if err
      @ourAdapter.describe(tableName, (err, definition)->
        return done(err) if err
        assert.equal(_.keys(definition).length, _.keys(oneMigrationDefinition).length)
        done()
      )
    )

  it 'should be able to run 2 migrations', (done)->
    done()

  afterEach (done)->
    @ourAdapter.drop(SchemaMigration::tableName, done)
