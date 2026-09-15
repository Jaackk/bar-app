import Foundation

public struct Ingredient: Codable, Hashable, Sendable, Identifiable {
    public var quantityDisplay: String? = nil
    public var id: String
    public var name: String
    public var amount: Double
    public var unit: MeasurementUnit
    public var batchable: Bool
    public var batchBehaviour: BatchBehaviour
    public var bottleSize: Double?
    public var notes: String
    public var prepComponent: String?

    public init(id: String = UUID().uuidString, name: String, amount: Double = 0, unit: MeasurementUnit = .ml, batchable: Bool = true, batchBehaviour: BatchBehaviour = .normal, bottleSize: Double? = nil, notes: String = "", prepComponent: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.batchable = batchable
        self.batchBehaviour = batchBehaviour
        self.bottleSize = bottleSize
        self.notes = notes
        self.prepComponent = prepComponent
    }

    enum CodingKeys: String, CodingKey { case quantityDisplay, id, name, amount, unit, batchable, batchBehaviour, bottleSize, notes, prepComponent }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        quantityDisplay = try c.decodeIfPresent(String.self, forKey: .quantityDisplay)
        id = try c.value(String.self, for: .id, default: UUID().uuidString)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.value(Double.self, for: .amount, default: 0)
        unit = try c.value(MeasurementUnit.self, for: .unit, default: .ml)
        batchable = try c.value(Bool.self, for: .batchable, default: true)
        batchBehaviour = try c.value(BatchBehaviour.self, for: .batchBehaviour, default: .normal)
        bottleSize = try c.decodeIfPresent(Double.self, forKey: .bottleSize)
        notes = try c.value(String.self, for: .notes, default: "")
        prepComponent = try c.decodeIfPresent(String.self, forKey: .prepComponent)
    }

    public var measurement: String { quantityDisplay ?? MeasurementFormatter.string(amount, unit: unit) }
    public var volumeML: Double? {
        switch unit { case .ml: return amount; case .cl: return amount * 10; case .litre: return amount * 1_000; default: return nil }
    }
}
