import Contacts
import WorkspaceContactsCore

/// Live `ContactStoreWriting` over CNContactStore. Tags every contact into a dedicated
/// "Imeto Directory" CNGroup (the source of truth for "remove all").
// @unchecked Sendable: CNContactStore is documented thread-safe; the struct's only stored
// property is that store, so it is safe to share across isolation domains.
struct CNContactStoreWriter: ContactStoreWriting, @unchecked Sendable {
    static let groupName = "Imeto Directory"
    static let companyName = "Imeto"

    private let store: CNContactStore
    init(store: CNContactStore = CNContactStore()) { self.store = store }

    /// Contacts access sufficient for what we do. iOS 18's `.limited` counts: Apple documents
    /// that limited-access apps may still create and modify contacts, and we only ever touch
    /// contacts we wrote ourselves — we never read the user's address book. Treating `.limited`
    /// as denied would break sync for anyone who picks "Select Contacts…".
    static var hasWriteAccess: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized { return true }
        if #available(iOS 18.0, *), status == .limited { return true }
        return false
    }

    func requestAccess() async -> Bool {
        // Ask, then judge by the resulting status rather than the Bool: under iOS 18 the user may
        // grant `.limited`, which is enough for us.
        _ = try? await store.requestAccess(for: .contacts)
        return Self.hasWriteAccess
    }

    func create(_ person: DirectoryPerson) throws -> String {
        let contact = CNMutableContact()
        Self.apply(person, to: contact)
        let save = CNSaveRequest()
        save.add(contact, toContainerWithIdentifier: nil)
        // Group membership is a convenience for "remove all", not a requirement: CNGroup
        // behavior under iOS 18 limited access is undocumented. The persisted ref map is the
        // real record of what we wrote, so an unavailable group must not fail the write.
        if let group = try? ensureGroup() { save.addMember(contact, to: group) }
        try store.execute(save)
        return contact.identifier
    }

    func update(identifier: String, with person: DirectoryPerson) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.fetchKeys),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactStoreError.notFound(identifier)
        }
        Self.apply(person, to: mutable)
        let save = CNSaveRequest()
        save.update(mutable)
        try store.execute(save)
    }

    func delete(identifier: String) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier,
                                                       keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactStoreError.notFound(identifier)
        }
        let save = CNSaveRequest()
        save.delete(mutable)
        try store.execute(save)
    }

    /// Delete every contact we wrote — never anything else. Two overlapping sources so neither
    /// alone is a single point of failure: the group's members (robust if the persisted map is
    /// lost) and `knownIdentifiers` from that map (robust if the group is missing or unavailable,
    /// e.g. under limited access). Deduped, so a contact in both is deleted once.
    func removeAll(knownIdentifiers: [String] = []) throws {
        let save = CNSaveRequest()
        var seen = Set<String>()
        var hasWork = false
        let idKeys = [CNContactIdentifierKey as CNKeyDescriptor]

        if let group = try? store.groups(matching: nil).first(where: { $0.name == Self.groupName }) {
            let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
            let members = (try? store.unifiedContacts(matching: predicate, keysToFetch: idKeys)) ?? []
            for m in members where seen.insert(m.identifier).inserted {
                if let mutable = m.mutableCopy() as? CNMutableContact {
                    save.delete(mutable)
                    hasWork = true
                }
            }
            if let mutableGroup = group.mutableCopy() as? CNMutableGroup {
                save.delete(mutableGroup)
                hasWork = true
            }
        }

        for id in knownIdentifiers where seen.insert(id).inserted {
            guard let existing = try? store.unifiedContact(withIdentifier: id, keysToFetch: idKeys),
                  let mutable = existing.mutableCopy() as? CNMutableContact else { continue }
            save.delete(mutable)
            hasWork = true
        }

        guard hasWork else { return }
        try store.execute(save)
    }

    // MARK: - Private

    private func ensureGroup() throws -> CNGroup {
        if let existing = try store.groups(matching: nil).first(where: { $0.name == Self.groupName }) {
            return existing
        }
        let group = CNMutableGroup()
        group.name = Self.groupName
        let save = CNSaveRequest()
        save.add(group, toContainerWithIdentifier: nil)
        try store.execute(save)
        return group
    }

    static var fetchKeys: [CNKeyDescriptor] {
        [
            CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey, CNContactOrganizationNameKey, CNContactJobTitleKey,
            CNContactDepartmentNameKey, CNContactIdentifierKey,
        ].map { $0 as CNKeyDescriptor }
    }

    private static func apply(_ person: DirectoryPerson, to c: CNMutableContact) {
        c.givenName = person.givenName ?? person.displayName
        c.familyName = person.familyName ?? ""
        c.organizationName = companyName
        c.jobTitle = person.organizationTitle ?? ""
        c.departmentName = person.department ?? ""
        c.phoneNumbers = person.phoneNumbers.map {
            CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: $0))
        }
        c.emailAddresses = person.emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
    }
}
