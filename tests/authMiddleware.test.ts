import { NextFunction, Request, Response } from "express";
import { authMiddleware } from "../src/middleware/auth.middleware";
import { JwtUtil } from "../src/utils/jwt.util";

jest.mock("../src/utils/jwt.util");

describe("authMiddleware", () => {
  let req: Partial<Request>;
  let res: Partial<Response>;
  let next: NextFunction;

  beforeEach(() => {
    req = { headers: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    next = jest.fn();
    jest.clearAllMocks();
  });

  it("devrait renvoyer 401 si aucun header Authorization n'est présent", () => {
    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Token d'authentification requis",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 401 si le header Authorization ne commence pas par 'Bearer '", () => {
    req.headers = { authorization: "InvalidToken" };

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Format de token invalide. Utilisez 'Bearer <token>'",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 401 si le token est vide après 'Bearer '", () => {
    req.headers = { authorization: "Bearer " };

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Token manquant",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 401 si le token est expiré", () => {
    req.headers = { authorization: "Bearer expiredToken" };

    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => {
        throw new Error("Le token a expiré");
      }),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Token expiré",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 401 si le token est invalide", () => {
    req.headers = { authorization: "Bearer invalidToken" };

    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => {
        throw new Error("Signature invalide");
      }),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Token invalide",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 500 pour une autre erreur d'authentification", () => {
    req.headers = { authorization: "Bearer someToken" };

    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => {
        throw new Error("Erreur inconnue");
      }),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Erreur d'authentification",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait appeler next() si le token est valide", () => {
    req.headers = { authorization: "Bearer validToken" };

    const mockPayload = { id: 1, email: "test@example.com", role: "USER" };
    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => mockPayload),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(req.user).toEqual(mockPayload);
    expect(next).toHaveBeenCalled();
  });
});
