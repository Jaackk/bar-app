import Foundation

public protocol CocktailRepository {
    func fetchCocktails(venueID: String) throws -> [Cocktail]
    func saveCocktail(_ cocktail: Cocktail, role: UserRole) throws
}
public protocol WineRepository {
    func fetchWines(venueID: String) throws -> [Wine]
    func saveWine(_ wine: Wine, role: UserRole) throws
}
public protocol PrepRepository {
    func fetchPrep(venueID: String) throws -> [PrepItem]
    func savePrep(_ item: PrepItem) throws
}
public protocol StockRepository {
    func fetchStock(venueID: String) throws -> [StockItem]
    func saveStock(_ item: StockItem, role: UserRole) throws
}
public protocol VenueRepository { func fetchVenues() throws -> [Venue] }
public protocol UserRepository {
    func fetchUser() throws -> User
    func savePreferences(_ preferences: UserPreferences) throws
}
public enum RepositoryError: LocalizedError {
    case permissionDenied
    case unknownRecord(String)
    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Your role does not allow this content change."
        case .unknownRecord(let id): return "Record not found: \(id)."
        }
    }
}

/// Local role checks are development foundations, not authentication or a server security boundary.
public final class LocalContentRepository: CocktailRepository, WineRepository, PrepRepository, StockRepository, VenueRepository, UserRepository {
    private let appRepository: any AppRepository
    public init(appRepository: any AppRepository) { self.appRepository = appRepository }
    public func fetchCocktails(venueID: String) throws -> [Cocktail] { VenueResolver.cocktails(try appRepository.load().cocktails, venueID: venueID) }
    public func fetchWines(venueID: String) throws -> [Wine] { try appRepository.load().wines.filter { $0.isActive && ($0.venueID == nil || $0.venueID == venueID) } }
    public func fetchPrep(venueID: String) throws -> [PrepItem] { try appRepository.load().prep.filter { $0.venueID == venueID } }
    public func fetchStock(venueID: String) throws -> [StockItem] { try appRepository.load().stock.filter { $0.venueID == venueID } }
    public func fetchVenues() throws -> [Venue] { try appRepository.load().venues }
    public func fetchUser() throws -> User { try appRepository.load().user }
    public func savePreferences(_ preferences: UserPreferences) throws {
        var snapshot = try appRepository.load(); snapshot.preferences = preferences; try appRepository.save(snapshot)
    }
    public func saveCocktail(_ cocktail: Cocktail, role: UserRole) throws {
        guard role.canEditContent else { throw RepositoryError.permissionDenied }
        var snapshot = try appRepository.load()
        if let index = snapshot.cocktails.firstIndex(where: { $0.id == cocktail.id }) { snapshot.cocktails[index] = cocktail }
        else { snapshot.cocktails.append(cocktail) }
        try appRepository.save(snapshot)
    }
    public func saveWine(_ wine: Wine, role: UserRole) throws {
        guard role.canEditContent else { throw RepositoryError.permissionDenied }
        var snapshot = try appRepository.load()
        if let index = snapshot.wines.firstIndex(where: { $0.id == wine.id }) { snapshot.wines[index] = wine }
        else { snapshot.wines.append(wine) }
        try appRepository.save(snapshot)
    }
    public func savePrep(_ item: PrepItem) throws {
        var snapshot = try appRepository.load()
        guard let index = snapshot.prep.firstIndex(where: { $0.id == item.id }) else { throw RepositoryError.unknownRecord(item.id) }
        snapshot.prep[index] = item; try appRepository.save(snapshot)
    }
    public func saveStock(_ item: StockItem, role: UserRole) throws {
        var snapshot = try appRepository.load()
        guard let index = snapshot.stock.firstIndex(where: { $0.id == item.id }) else { throw RepositoryError.unknownRecord(item.id) }
        var old = snapshot.stock[index]
        if role.canEditContent { old = item }
        else { old.currentStock = item.currentStock }
        snapshot.stock[index] = old; try appRepository.save(snapshot)
    }
}
