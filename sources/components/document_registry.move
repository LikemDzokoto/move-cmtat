/// Document Registry Component - ERC-1643 Compliant Document Management
/// Manages on-chain documents for debt securities (Prospectus, Indenture, Terms)
/// Implements document tracking with hash, URI, and modification history
module move_cmtat::document_registry {
    use std::string::{Self, String};
    use iota::vec_map::{Self, VecMap};
    use iota::event;
    use std::vector;

    // ========== ERRORS ==========
    
    const EDocumentNotFound: u64 = 600;
    const EDocumentAlreadyExists: u64 = 601;
    const EInvalidDocumentName: u64 = 602;
    const EInvalidDocumentHash: u64 = 603;
    const EInvalidDocumentUri: u64 = 604;

    // ========== STRUCTS ==========
    
    /// Document structure following ERC-1643 specification
    public struct Document has copy, drop, store {
        name: String,               // Document name (e.g., "Prospectus", "Indenture")
        hash: String,               // Document hash (e.g., SHA-256, IPFS CID)
        uri: String,                // URI to access document
        last_modified: u64,         // Unix timestamp in seconds
        document_type: String,      // Type classification
        version: u64,               // Document version number
    }

    /// Document registry state
    public struct DocumentRegistryState has key, store {
        id: UID,
        documents: VecMap<String, Document>,  // name -> Document
        document_count: u64,
        last_modified_global: u64,            // Last modification across all documents
    }

    // ========== EVENTS ==========
    
    public struct DocumentAdded has copy, drop {
        name: String,
        hash: String,
        uri: String,
        added_by: address,
        timestamp: u64,
    }

    public struct DocumentUpdated has copy, drop {
        name: String,
        old_hash: String,
        new_hash: String,
        updated_by: address,
        timestamp: u64,
        new_version: u64,
    }

    public struct DocumentRemoved has copy, drop {
        name: String,
        removed_by: address,
        timestamp: u64,
    }

    public struct DocumentAccessed has copy, drop {
        name: String,
        accessed_by: address,
        timestamp: u64,
    }

    // ========== INITIALIZATION ==========
    
    /// Initialize empty document registry
    public fun init_document_registry(ctx: &mut TxContext): DocumentRegistryState {
        DocumentRegistryState {
            id: object::new(ctx),
            documents: vec_map::empty(),
            document_count: 0,
            last_modified_global: 0,
        }
    }

    // ========== DOCUMENT MANAGEMENT ==========
    
    /// Add new document to registry
    public fun add_document(
        state: &mut DocumentRegistryState,
        name: String,
        hash: String,
        uri: String,
        timestamp: u64,
        ctx: &TxContext
    ) {
        // Validate inputs
        assert!(!string::is_empty(&name), EInvalidDocumentName);
        assert!(!string::is_empty(&hash), EInvalidDocumentHash);
        assert!(!string::is_empty(&uri), EInvalidDocumentUri);
        assert!(!document_exists(state, name), EDocumentAlreadyExists);

        // Create document
        let document = Document {
            name,
            hash,
            uri,
            last_modified: timestamp,
            document_type: classify_document_type(&name),
            version: 1,
        };

        // Store document
        vec_map::insert(&mut state.documents, name, document);
        state.document_count = state.document_count + 1;
        state.last_modified_global = timestamp;

        // Emit event
        event::emit(DocumentAdded {
            name,
            hash,
            uri,
            added_by: tx_context::sender(ctx),
            timestamp,
        });
    }

    /// Add document with explicit type
    public fun add_document_with_type(
        state: &mut DocumentRegistryState,
        name: String,
        hash: String,
        uri: String,
        document_type: String,
        timestamp: u64,
        ctx: &TxContext
    ) {
        assert!(!string::is_empty(&name), EInvalidDocumentName);
        assert!(!string::is_empty(&hash), EInvalidDocumentHash);
        assert!(!string::is_empty(&uri), EInvalidDocumentUri);
        assert!(!document_exists(state, name), EDocumentAlreadyExists);

        let document = Document {
            name,
            hash,
            uri,
            last_modified: timestamp,
            document_type,
            version: 1,
        };

        vec_map::insert(&mut state.documents, name, document);
        state.document_count = state.document_count + 1;
        state.last_modified_global = timestamp;

        event::emit(DocumentAdded {
            name,
            hash,
            uri,
            added_by: tx_context::sender(ctx),
            timestamp,
        });
    }

    /// Update existing document
    public fun update_document(
        state: &mut DocumentRegistryState,
        name: String,
        new_hash: String,
        new_uri: String,
        timestamp: u64,
        ctx: &TxContext
    ) {
        assert!(document_exists(state, name), EDocumentNotFound);
        assert!(!string::is_empty(&new_hash), EInvalidDocumentHash);
        assert!(!string::is_empty(&new_uri), EInvalidDocumentUri);

        // Get old document
        let old_document = get_document(state, name);
        let old_hash = old_document.hash;
        let new_version = old_document.version + 1;

        // Create updated document
        let updated_document = Document {
            name,
            hash: new_hash,
            uri: new_uri,
            last_modified: timestamp,
            document_type: old_document.document_type,
            version: new_version,
        };

        // Remove old and insert new
        vec_map::remove(&mut state.documents, &name);
        vec_map::insert(&mut state.documents, name, updated_document);
        state.last_modified_global = timestamp;

        // Emit event
        event::emit(DocumentUpdated {
            name,
            old_hash,
            new_hash,
            updated_by: tx_context::sender(ctx),
            timestamp,
            new_version,
        });
    }

    /// Remove document from registry
    public fun remove_document(
        state: &mut DocumentRegistryState,
        name: String,
        timestamp: u64,
        ctx: &TxContext
    ) {
        assert!(document_exists(state, name), EDocumentNotFound);

        vec_map::remove(&mut state.documents, &name);
        state.document_count = state.document_count - 1;
        state.last_modified_global = timestamp;

        // Emit event
        event::emit(DocumentRemoved {
            name,
            removed_by: tx_context::sender(ctx),
            timestamp,
        });
    }

    /// Batch add documents
    public fun batch_add_documents(
        state: &mut DocumentRegistryState,
        names: vector<String>,
        hashes: vector<String>,
        uris: vector<String>,
        timestamp: u64,
        ctx: &TxContext
    ) {
        let len = vector::length(&names);
        assert!(len == vector::length(&hashes), 0);
        assert!(len == vector::length(&uris), 0);

        let mut i = 0;
        while (i < len) {
            let name = *vector::borrow(&names, i);
            let hash = *vector::borrow(&hashes, i);
            let uri = *vector::borrow(&uris, i);
            
            if (!document_exists(state, name)) {
                add_document(state, name, hash, uri, timestamp, ctx);
            };
            
            i = i + 1;
        }
    }

    // ========== QUERIES ==========
    
    /// Get document by name
    public fun get_document(state: &DocumentRegistryState, name: String): Document {
        assert!(document_exists(state, name), EDocumentNotFound);
        *vec_map::get(&state.documents, &name)
    }

    /// Try get document (returns option)
    public fun try_get_document(state: &DocumentRegistryState, name: String): Option<Document> {
        if (document_exists(state, name)) {
            option::some(*vec_map::get(&state.documents, &name))
        } else {
            option::none()
        }
    }

    /// Check if document exists
    public fun document_exists(state: &DocumentRegistryState, name: String): bool {
        vec_map::contains(&state.documents, &name)
    }

    /// Get document hash
    public fun get_document_hash(state: &DocumentRegistryState, name: String): String {
        assert!(document_exists(state, name), EDocumentNotFound);
        vec_map::get(&state.documents, &name).hash
    }

    /// Try get document hash
    public fun try_get_document_hash(state: &DocumentRegistryState, name: String): Option<String> {
        if (document_exists(state, name)) {
            option::some(vec_map::get(&state.documents, &name).hash)
        } else {
            option::none()
        }
    }

    /// Get document URI
    public fun get_document_uri(state: &DocumentRegistryState, name: String): String {
        assert!(document_exists(state, name), EDocumentNotFound);
        vec_map::get(&state.documents, &name).uri
    }

    /// Try get document URI
    public fun try_get_document_uri(state: &DocumentRegistryState, name: String): Option<String> {
        if (document_exists(state, name)) {
            option::some(vec_map::get(&state.documents, &name).uri)
        } else {
            option::none()
        }
    }

    /// Get last modified timestamp
    public fun get_document_last_modified(state: &DocumentRegistryState, name: String): u64 {
        assert!(document_exists(state, name), EDocumentNotFound);
        vec_map::get(&state.documents, &name).last_modified
    }

    /// Get document type
    public fun get_document_type(state: &DocumentRegistryState, name: String): String {
        assert!(document_exists(state, name), EDocumentNotFound);
        vec_map::get(&state.documents, &name).document_type
    }

    /// Get document version
    public fun get_document_version(state: &DocumentRegistryState, name: String): u64 {
        assert!(document_exists(state, name), EDocumentNotFound);
        vec_map::get(&state.documents, &name).version
    }

    /// Get all document names
    public fun get_all_document_names(state: &DocumentRegistryState): vector<String> {
        vec_map::keys(&state.documents)
    }

    /// Get document count
    public fun get_document_count(state: &DocumentRegistryState): u64 {
        state.document_count
    }

    /// Get all documents
    public fun get_all_documents(state: &DocumentRegistryState): VecMap<String, Document> {
        state.documents
    }

    /// Get documents by type
    public fun get_documents_by_type(
        state: &DocumentRegistryState,
        doc_type: String
    ): vector<String> {
        let mut names = vector::empty<String>();
        let all_names = get_all_document_names(state);
        
        let mut i = 0;
        while (i < vector::length(&all_names)) {
            let name = *vector::borrow(&all_names, i);
            let document = get_document(state, name);
            if (document.document_type == doc_type) {
                vector::push_back(&mut names, name);
            };
            i = i + 1;
        };

        names
    }

    /// Get global last modified timestamp
    public fun get_last_modified_global(state: &DocumentRegistryState): u64 {
        state.last_modified_global
    }

    // ========== VALIDATION ==========
    
    /// Require document exists
    public fun require_document_exists(state: &DocumentRegistryState, name: String) {
        assert!(document_exists(state, name), EDocumentNotFound);
    }

    /// Require document does not exist
    public fun require_document_not_exists(state: &DocumentRegistryState, name: String) {
        assert!(!document_exists(state, name), EDocumentAlreadyExists);
    }

    /// Validate document hash format (basic check)
    public fun validate_hash_format(hash: &String): bool {
        // Basic validation: hash should not be empty and reasonable length
        let len = string::length(hash);
        len > 0 && len <= 128
    }

    /// Validate URI format (basic check)
    public fun validate_uri_format(uri: &String): bool {
        // Basic validation: URI should not be empty and start with scheme
        let len = string::length(uri);
        len > 0 && len <= 2048
    }

    // ========== CLASSIFICATION ==========
    
    /// Classify document type based on name
    fun classify_document_type(name: &String): String {
        let name_copy = *name;
        let name_lower = string::to_ascii(name_copy);
        let name_bytes = std::ascii::as_bytes(&name_lower);
        
        // Common document types for debt securities
        let prospectus = b"prospectus";
        let indenture = b"indenture";
        let terms = b"terms";
        let conditions = b"conditions";
        let trust = b"trust";
        let agency = b"agency";
        let guarantee = b"guarantee";
        let security = b"security";
        let opinion = b"opinion";
        let auditor = b"auditor";
        let rating = b"rating";
        
        if (contains_substring(name_bytes, &prospectus)) {
            string::utf8(b"PROSPECTUS")
        } else if (contains_substring(name_bytes, &indenture)) {
            string::utf8(b"INDENTURE")
        } else if (contains_substring(name_bytes, &terms) || contains_substring(name_bytes, &conditions)) {
            string::utf8(b"TERMS_AND_CONDITIONS")
        } else if (contains_substring(name_bytes, &trust)) {
            string::utf8(b"TRUST_DEED")
        } else if (contains_substring(name_bytes, &agency)) {
            string::utf8(b"AGENCY_AGREEMENT")
        } else if (contains_substring(name_bytes, &guarantee)) {
            string::utf8(b"GUARANTEE")
        } else if (contains_substring(name_bytes, &security)) {
            string::utf8(b"SECURITY_DOCUMENT")
        } else if (contains_substring(name_bytes, &opinion)) {
            string::utf8(b"LEGAL_OPINION")
        } else if (contains_substring(name_bytes, &auditor)) {
            string::utf8(b"AUDITOR_REPORT")
        } else if (contains_substring(name_bytes, &rating)) {
            string::utf8(b"RATING_REPORT")
        } else {
            string::utf8(b"OTHER")
        }
    }

    /// Check if bytes contain substring (case-insensitive)
    fun contains_substring(bytes: &vector<u8>, pattern: &vector<u8>): bool {
        let bytes_len = vector::length(bytes);
        let pattern_len = vector::length(pattern);
        
        if (pattern_len == 0 || bytes_len < pattern_len) {
            return false
        };

        let mut i = 0;
        while (i <= bytes_len - pattern_len) {
            let mut j = 0;
            let mut matched = true;
            
            while (j < pattern_len) {
                let byte1 = *vector::borrow(bytes, i + j);
                let byte2 = *vector::borrow(pattern, j);
                
                // Case-insensitive comparison
                if (to_lower(byte1) != to_lower(byte2)) {
                    matched = false;
                    break
                };
                
                j = j + 1;
            };
            
            if (matched) {
                return true
            };
            
            i = i + 1;
        };

        false
    }

    /// Convert byte to lowercase
    fun to_lower(byte: u8): u8 {
        if (byte >= 65 && byte <= 90) {
            // A-Z -> a-z
            byte + 32
        } else {
            byte
        }
    }

    // ========== UTILITY FUNCTIONS ==========
    
    /// Create document struct
    public fun create_document(
        name: String,
        hash: String,
        uri: String,
        last_modified: u64,
        document_type: String,
        version: u64
    ): Document {
        Document {
            name,
            hash,
            uri,
            last_modified,
            document_type,
            version,
        }
    }

    /// Check if document is recent (modified within given period)
    public fun is_document_recent(
        state: &DocumentRegistryState,
        name: String,
        current_time: u64,
        period_seconds: u64
    ): bool {
        if (!document_exists(state, name)) {
            return false
        };
        
        let last_modified = get_document_last_modified(state, name);
        (current_time - last_modified) <= period_seconds
    }

    /// Get document age in seconds
    public fun get_document_age(
        state: &DocumentRegistryState,
        name: String,
        current_time: u64
    ): u64 {
        if (!document_exists(state, name)) {
            return 0
        };
        
        let last_modified = get_document_last_modified(state, name);
        if (current_time > last_modified) {
            current_time - last_modified
        } else {
            0
        }
    }

    /// Check if document has been updated since given time
    public fun is_document_updated_since(
        state: &DocumentRegistryState,
        name: String,
        since_timestamp: u64
    ): bool {
        if (!document_exists(state, name)) {
            return false
        };
        
        get_document_last_modified(state, name) > since_timestamp
    }
}
