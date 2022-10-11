import Vapor




// configures your application
public func configure(_ app: Application) throws  {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
        do {
            try app.initializeMongoDB(connectionString: "mongodb://localhost:2717/sure")
            try routes(app)
        } catch  {
            Logger(label: "MongoDB Error").error("Failed to connect mongoDB")
        }
    
}
