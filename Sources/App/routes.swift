import Vapor

func routes(_ app: Application) throws {
    app.get("get") { req async -> String in
        print("received the request")
        return "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    app.get("") { req in
        "Welcome to SURE."
    }
    
    DiscussionController.routes(app)
    ReadingController.routes(app)
    ChatController.routes(app)
    UserController.routes(app)
    CommentController.routes(app)
    GroupController.routes(app)
}
