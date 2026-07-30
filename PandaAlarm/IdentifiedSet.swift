//
//  IdentifiedSet.swift
//  PandaAlarm
//
//  Created by Gavin John on 7/29/26.
//

struct IdentifiedSet<Element: Identifiable> {
    private var storage: [Element.ID: Element]

    init() {
        storage = [:]
    }

    init<S: Sequence>(_ elements: S) where S.Element == Element {
        storage = Dictionary(uniqueKeysWithValues: elements.map { ($0.id, $0) })
    }

    @discardableResult
    mutating func insert(_ element: Element) -> Element? {
        let old = storage[element.id]
        storage[element.id] = element
        return old
    }

    @discardableResult
    mutating func remove(_ element: Element) -> Element? {
        storage.removeValue(forKey: element.id)
    }

    @discardableResult
    mutating func remove(id: Element.ID) -> Element? {
        storage.removeValue(forKey: id)
    }

    func contains(id: Element.ID) -> Bool {
        storage[id] != nil
    }

    func contains(_ element: Element) -> Bool {
        storage[element.id] != nil
    }

    subscript(id: Element.ID) -> Element? {
        get { storage[id] }
        set { storage[id] = newValue }
    }

    var ids: Dictionary<Element.ID, Element>.Keys { storage.keys }
    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
}

extension IdentifiedSet: Sequence {
    func makeIterator() -> Dictionary<Element.ID, Element>.Values.Iterator {
        storage.values.makeIterator()
    }
}

extension IdentifiedSet: Collection {
    typealias Index = Dictionary<Element.ID, Element>.Index

    var startIndex: Index { storage.startIndex }
    var endIndex: Index { storage.endIndex }
    func index(after i: Index) -> Index { storage.index(after: i) }
    subscript(position: Index) -> Element { storage[position].value }
}

extension IdentifiedSet: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension IdentifiedSet: Equatable where Element: Equatable {}
extension IdentifiedSet: Hashable where Element: Hashable {
    func hash(into hasher: inout Hasher) {
        for element in storage.values { hasher.combine(element) }
    }
}
