import { NextFunction, Request, Response } from "express";
import {
  adminMiddleware,
  authMiddleware,
} from "../src/middleware/auth.middleware";
import { JwtUtil } from "../src/utils/jwt.util";

// Mock de JwtUtil
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
      message: "Token d'authentification requis",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait renvoyer 401 si le token est invalide", () => {
    req.headers = { authorization: "Bearer fakeToken" };

    // On force JwtUtil à lancer une erreur
    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => {
        throw new Error("Invalid token");
      }),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Token invalide ou expiré",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait appeler next() si le token est valide", () => {
    req.headers = { authorization: "Bearer validToken" };

    const mockPayload = { id: 1, role: "USER" };
    (JwtUtil as jest.Mock).mockImplementation(() => ({
      verifyAccessToken: jest.fn(() => mockPayload),
    }));

    authMiddleware(req as Request, res as Response, next);

    expect(req.user).toEqual(mockPayload);
    expect(next).toHaveBeenCalled();
  });
});

describe("adminMiddleware", () => {
  let req: Partial<Request>;
  let res: Partial<Response>;
  let next: NextFunction;

  beforeEach(() => {
    req = {};
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    next = jest.fn();
    jest.clearAllMocks();
  });

  it("devrait renvoyer 403 si l'utilisateur n'est pas ADMIN", () => {
    req.user = { id: 1, role: "USER" } as any;

    adminMiddleware(req as Request, res as Response, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Accès administrateur requis",
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("devrait appeler next() si l'utilisateur est ADMIN", () => {
    req.user = { id: 1, role: "ADMIN" } as any;

    adminMiddleware(req as Request, res as Response, next);

    expect(next).toHaveBeenCalled();
  });
});
