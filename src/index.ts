// src/app.ts
import cors from "cors";
import dotenv from "dotenv";
import express from "express";
import helmet from "helmet";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerUi from "swagger-ui-express";
import authRoutes from "./routes/auth.routes";

// Configuration des variables d'environnement
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration Swagger corrigée
const swaggerOptions = {
  definition: {
    // "definition" au lieu de "swaggerDefinition"
    openapi: "3.0.0",
    info: {
      title: "My Express.js API",
      version: "1.0.0",
      description: "A sample Express.js API built with TypeScript and Swagger",
    },
    servers: [
      {
        url: `http://localhost:${PORT}`,
        description: "Development server",
      },
    ],
  },
  apis: [
    "./src/routes/*.ts", // Chemin relatif
    "./dist/routes/*.js", // Pour la version compilée
    "src/routes/*.ts", // Alternative sans ./
  ],
};

const swaggerDocs = swaggerJsdoc(swaggerOptions);

app.use(helmet());
app.use(
  cors({
    origin: process.env.FRONTEND_URL || "http://localhost:5173",
    credentials: true,
  })
);

app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// Swagger UI
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocs));

// Routes
app.use("/api/auth", authRoutes);

app.get("/health", (req, res) => {
  res.json({
    success: true,
    message: "Server is running",
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route non trouvée",
  });
});

// Error handler
app.use(
  (
    error: any,
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ) => {
    console.error("Erreur globale:", error);
    res.status(error.status || 500).json({
      success: false,
      message: error.message || "Erreur interne du serveur",
      ...(process.env.NODE_ENV === "development" && { stack: error.stack }),
    });
  }
);

// Démarrage du serveur
app.listen(PORT, () => {
  console.log(`🚀 Serveur démarré sur le port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`📚 Swagger docs: http://localhost:${PORT}/api-docs`);
});

export default app;
