// Copyright (c) 2017 Evgeny Kubrakov
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import CoreData

enum ManagedObjectContextSaveError : Error {
    case rootParentContextHasNoPersistentStoreCoordinator
}

public typealias ManagedObjectContextBlock = (_ managedObjectContext: NSManagedObjectContext) -> Void

extension NSManagedObjectContext {
    
    // MARK: NSManagedObjectContext Related Methods
    
    public static var defaultMainQueueContext: NSManagedObjectContext? {
        return CoreDataStack.defaultStack?.mainQueueContext
    }
    
    public static func makeWorkerContext() -> NSManagedObjectContext? {
        return CoreDataStack.defaultStack?.makeWorkerContext()
    }
    
    public static func performInMainQueueContextAndSave(block: @escaping ManagedObjectContextBlock) {
        self.defaultMainQueueContext?.performAndWait {
            self.defaultMainQueueContext?.performUnsafeAndSave(block: block)
        }
    }
    
    public static func performInWorkerContextAndSave(block: @escaping ManagedObjectContextBlock) {
        let workerContext = self.makeWorkerContext()
        workerContext?.perform {
            workerContext?.performUnsafeAndSave(block: block)
        }
    }
    
    public func saveContextChangesToPersistentStore() throws {
        
        if self.hasChanges {
            
            var contextToSave: NSManagedObjectContext? = self
            
            while contextToSave != nil {
                
                var saveError: Error? = nil
                contextToSave?.performAndWait {
                    do {
                        try contextToSave?.save()
                    } catch {
                        saveError = error
                    }
                }
                
                if let safeSaveError = saveError {
                    throw safeSaveError
                }
                
                if contextToSave?.parent == nil && contextToSave?.persistentStoreCoordinator == nil {
                    throw(ManagedObjectContextSaveError.rootParentContextHasNoPersistentStoreCoordinator)
                }
                
                contextToSave = contextToSave?.parent
                
            }
            
        }
        
    }
    
    // MARK: NSManagedObject Related Methods
    
    public func insertObject<T: NSManagedObject>(with managedClass: T.Type) -> T? {
        let newObject = NSEntityDescription.insertNewObject(forEntityName: managedClass.entityName(), into: self) as? T
        return newObject
    }
    
    public func fetchObject<T: NSManagedObject>(with managedClass: T.Type, predicate: NSPredicate) -> T? {
        let fetchedObject = self.fetchObjects(with: managedClass,
                                              predicate: predicate,
                                              fetchLimit: 1)?.first
        return fetchedObject;
    }
    
    public func fetchOrInsertObject<T: NSManagedObject>(with managedClass: T.Type, predicate: NSPredicate) -> T? {
        var fetchedObject = self.fetchObjects(with: managedClass, predicate: predicate, fetchLimit: 1)?.first
        if fetchedObject == nil {
            fetchedObject = self.insertObject(with: managedClass)
        }
        return fetchedObject
    }
    
    public func fetchObjects<T: NSManagedObject>(with managedClass: T.Type,
                             predicate: NSPredicate? = nil,
                             fetchLimit: Int = 0,
                             sortDescriptors: [NSSortDescriptor]? = nil) -> [T]? {
        
        let fetchRequest = NSFetchRequest<T>(entityName: T.entityName())
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.sortDescriptors = sortDescriptors;
        
        var fetchedObjects: [T]?
        do {
            fetchedObjects = try self.fetch(fetchRequest)
        } catch {
            print(error)
        }
        
        return fetchedObjects
        
    }
    
    public func fetchObjectsAsynchronously<T: NSManagedObject>(with managedClass: T.Type,
                                           predicate: NSPredicate? = nil,
                                           fetchLimit: Int = 0,
                                           sortDescriptors: [NSSortDescriptor]? = nil,
                                           success: @escaping (_ fetchedObjects: [T]?) -> Void) -> Bool {
        
        let fetchRequest = NSFetchRequest<T>(entityName: T.entityName())
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.sortDescriptors = sortDescriptors;
        
        let asyncFetchRequest = NSAsynchronousFetchRequest<T>(fetchRequest: fetchRequest) { asyncFetchResult in
            let fetchedObjects = asyncFetchResult.finalResult
            success(fetchedObjects)
        }
        
        var preliminarySuccess = true
        do {
            _ = try self.execute(asyncFetchRequest)
        }
        catch {
            print("Asynchronous fetch error \(error)")
            preliminarySuccess = false
        }
        return preliminarySuccess
        
    }
    
    public func deleteObjects<T: NSManagedObject>(with managedClass: T.Type, predicate: NSPredicate? = nil) {
        
        let fetchedObjects = self.fetchObjects(with: managedClass)
        
        guard let safeResult = fetchedObjects else {
            return
        }
        
        for objectToDelete in safeResult {
            self.delete(objectToDelete)
        }
        
    }
    
    // MARK: Private Methods
    
    private func performUnsafeAndSave(block: @escaping ManagedObjectContextBlock) {
        block(self)
        do {
            try self.saveContextChangesToPersistentStore()
        } catch {
            print(error)
        }
    }
    
    
}
