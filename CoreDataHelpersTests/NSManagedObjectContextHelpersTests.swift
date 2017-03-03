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

import XCTest
import CoreData
@testable import CoreDataHelpers

class NSManagedObjectContextHelpersTests: XCTestCase {
    
    override func setUp() {
        if CoreDataStack.defaultStack == nil {
            CoreDataStack.defaultStack = CoreDataStack(modelFileName: CoreDataHelpersTests.testModelFileName,
                                                       bundle: Bundle(for: type(of: self)),
                                                       persistanceStoreFileName: "test.sqlite")
        }
    }
    
    override func tearDown() {
        NSManagedObjectContext.performInMainQueueContextAndSave { context in
            context.deleteObjects(with: TestEntity.self)
        }
    }
    
    func test_defaultMainQueueContext() {
        XCTAssertNotNil(NSManagedObjectContext.defaultMainQueueContext)
    }
    
    func test_makeWorkerContext() {
        XCTAssertNotNil(NSManagedObjectContext.makeWorkerContext())
    }
    
    func test_performInMainQueueContextAndSave() {
        let expectation = self.expectation(description: "Action performed")
        NSManagedObjectContext.performInWorkerContextAndSave { context in
            XCTAssertNotNil(context)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.0) { error in
            XCTAssertNil(error)
        }
    }
    
    func test_performInWorkerContextAndSave() {
        let expectation = self.expectation(description: "Action performed")
        NSManagedObjectContext.performInWorkerContextAndSave { context in
            XCTAssertNotNil(context)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.5) { error in
            if error != nil {
                print("\(#function) \(error)")
            }
            XCTAssertNil(error)
        }
    }
    
    func testWorkerContext_saveContextChangesToPersistentStore() {
        let workerContext = NSManagedObjectContext.makeWorkerContext()
        workerContext?.performAndWait {
            do {
                try workerContext?.saveContextChangesToPersistentStore()
            } catch {
                print("\(#function) \(error)")
                XCTAssertTrue(false)
            }
        }
    }
    
    func testWorkerContext_insertObject() {
        NSManagedObjectContext.performInWorkerContextAndSave { context in
            let newTestEntity = context.insertObject(with: TestEntity.self)
            XCTAssertNotNil(newTestEntity)
        };
    }
    
    func testMainContext_fetchObject() {
        
        let searchQuery = "test"
        
        NSManagedObjectContext.performInWorkerContextAndSave { context in
            let newTestEntity = context.insertObject(with: TestEntity.self)
            newTestEntity?.testEntityAttribute = searchQuery
        };
        
        let predicate = NSPredicate(format: "testEntityAttribute == %@", searchQuery)
        let fetchedObjects = NSManagedObjectContext.defaultMainQueueContext?.fetchObjects(with: TestEntity.self,
                                                                                          predicate: predicate)
        XCTAssertNotNil(fetchedObjects)
        
    }
    
    func testMainContext_fetchObjectsAsynchronously() {
        
        NSManagedObjectContext.performInMainQueueContextAndSave { context in
            let searchQuery = "test"
            let newTestEntity = context.insertObject(with: TestEntity.self)
            newTestEntity?.testEntityAttribute = searchQuery
        };
        
        let expectation = self.expectation(description: "Action performed")
        let preliminarySuccess = NSManagedObjectContext.defaultMainQueueContext?.fetchObjectsAsynchronously(with: TestEntity.self) { fetchedObjects in
            XCTAssertFalse(fetchedObjects?.count == 0)
            expectation.fulfill()
        }
        
        XCTAssertNotNil(preliminarySuccess)
        XCTAssertTrue(preliminarySuccess!)
        
        self.waitForExpectations(timeout: 0.5) { error in
            if error != nil {
                print("\(#function) \(error)")
            }
            XCTAssertNil(error)
        }
        
    }
    
    func testMainContext_deleteObjects() {
        NSManagedObjectContext.performInMainQueueContextAndSave { context in
            _ = context.insertObject(with: TestEntity.self)
            context.deleteObjects(with: TestEntity.self)
            let fetchedObjects = context.fetchObjects(with: TestEntity.self)
            XCTAssertTrue(fetchedObjects?.count == 0)
        }
    }
    
}
