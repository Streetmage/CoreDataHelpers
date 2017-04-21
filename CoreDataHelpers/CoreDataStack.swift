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

/*
 *         CoreData Stack that is used
 *-------------------------------------------------
 *            | Main Queue Context | < - - - Merge Changes From Notification - - -
 *                      |                                                         '
 *                      V                                                         |
 *    | Writer Context (Private Queue Context) | <-- | Worker Context for Async Operations (Private Queue Context) |
 *                      |
 *                      V
 *        | Persistent Store Coordinator |
 *-------------------------------------------------
 */

open class CoreDataStack {
    
    // MARK: Public Properties
    
    public static var defaultStack: CoreDataStack?
    
    public var mainQueueContext: NSManagedObjectContext?
    
    // MARK: Private Properties
    
    private var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    private var persistentStoreCoordinatorContext: NSManagedObjectContext?
    
    // MARK: Public Methods
    
    public required init? (modelFileName: String, bundle: Bundle, persistanceStoreFileName: String) {
        
        let modelUrl = bundle.url(forResource: modelFileName, withExtension: "momd")
        
        guard let safeModelUrl = modelUrl else {
            return
        }
        
        let managedObjectModel = NSManagedObjectModel(contentsOf: safeModelUrl)
        
        guard let safeObjectModel = managedObjectModel else {
            return
        }
        
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: safeObjectModel)
        
        var persistenceStorePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        persistenceStorePath?.append("/\(persistanceStoreFileName)")
        
        guard let safePersistenceStorePath = persistenceStorePath else {
            return
        }
        
        let persistentStoreUrl = URL(fileURLWithPath: safePersistenceStorePath)
        
        self.addPersistentStore(at: persistentStoreUrl)
        
        persistentStoreCoordinatorContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistentStoreCoordinatorContext?.persistentStoreCoordinator = persistentStoreCoordinator
        
        mainQueueContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainQueueContext?.parent = persistentStoreCoordinatorContext
        
    }
    
    open func makeWorkerContext () -> NSManagedObjectContext? {
        
        guard let safePersistentStoreCoordinator = self.persistentStoreCoordinator else {
            return nil
        }
        
        let privateQueueContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateQueueContext.persistentStoreCoordinator = safePersistentStoreCoordinator
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(workerContextDidSave(notification:)),
                                               name: NSNotification.Name.NSManagedObjectContextDidSave,
                                               object: nil)
        return privateQueueContext;
    }
    
    // MARK: Private Methods
    
    @objc private func workerContextDidSave (notification: Notification) {
        self.mainQueueContext?.mergeChanges(fromContextDidSave: notification)
    }
    
    private func addPersistentStore(at persistenceStoreUrl: URL, flushIfError: Bool = true) {
        
        do {
            try self.persistentStoreCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType,
                                                                    configurationName: nil,
                                                                    at: persistenceStoreUrl,
                                                                    options: nil)
        } catch {
            print("Cannot add persistent store with error \(error)")
            if flushIfError {
                self.removePersistentStore(at: persistenceStoreUrl)
                self.addPersistentStore(at: persistenceStoreUrl, flushIfError: false)
            }
        }
        
    }
    
    private func removePersistentStore(at persistenceStoreUrl: URL) {
        do {
            try FileManager.default.removeItem(at: persistenceStoreUrl)
        } catch {
            print("Cannot remove persistent store with error \(error)")
        }
    }
    
}
