import Vapor




// configures your application
public func configure(_ app: Application) throws  {
    // uncomment to serve files from /Public folder
        do {
            try app.initializeMongoDB(connectionString: DBConfig.url)
            
        } catch  {
            Logger(label: "MongoDB Error").error("Failed to connect mongoDB")
        }
    try routes(app)
}
