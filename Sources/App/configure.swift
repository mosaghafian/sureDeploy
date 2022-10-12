import Vapor




// configures your application
public func configure(_ app: Application) throws  {
    // uncomment to serve files from /Public folder
        do {
            try app.initializeMongoDB(connectionString: "mongodb://sasaCompany:Parvardegar1@localhost:2717/sure")
            
        } catch  {
            Logger(label: "MongoDB Error").error("Failed to connect mongoDB")
        }
    try routes(app)
}
