//
//  RemoteFeedLoaderTests.swift
//  EssentialFeedTests
//
//  Created by chihyin wang on 2020/7/30.
//  Copyright © 2020 chihyinwang. All rights reserved.
//

import XCTest
import EssentialFeed

class LoadFeedFromRemoteUseCaseTests: XCTestCase {
    
    func test_map_throwsErrorOnNon200HTTPResponse() throws {
        let json = makeItemJSON([])
        let samples = [199, 201, 300, 400, 500]
        
        try samples.forEach { code in
            XCTAssertThrowsError(
                try FeedItemMapper.map(json, from: HTTPURLResponse(statusCode: code))
            )
        }
    }
    
    func test_map_throwsErrorOn200HTTPResponseWithInvalidJSON() {
        let invalidJSON = Data("Invalid JSON".utf8)
        
        XCTAssertThrowsError(
            try FeedItemMapper.map(invalidJSON, from: HTTPURLResponse(statusCode: 200))
        )
    }
    
    func test_map_deliversNoItemsOn200HTTPResponseWithEmptyJSONList() throws {
        let emptyListJSON = makeItemJSON([])
        
        let result = try FeedItemMapper.map(emptyListJSON, from: HTTPURLResponse(statusCode: 200))

        XCTAssertEqual(result, [])
    }
    
    func test_load_deliversItemsOn200HTTPResponseWithJSONItems() {
        let (sut, client) = makeSUT()
        
        let item1 = makeItem(id: UUID(),
                             imageURL: URL(string: "https://a-url.com")!)
        
        let item2 = makeItem(id: UUID(),
                             description: "description",
                             location: "location",
                             imageURL: URL(string: "https://another-url.com")!)
        
        let items = [item1.model, item2.model]
        
        expect(sut: sut, toCompleteWith: .success(items), when: {
            let json = makeItemJSON([item1.json, item2.json])
            client.complete(withStatusCode: 200, data: json)
        })
    }
    
    // MARK: - Helpers
    
    private func makeSUT(url: URL = URL(string: "https://a-url.com")!, file: StaticString = #file, line: UInt = #line) -> (sut: RemoteFeedLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedLoader(url: url, client: client)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(client, file: file, line: line)
        return (sut, client)
    }
    
    private func failure(_ error: RemoteFeedLoader.Error) -> RemoteFeedLoader.Result {
        return .failure(error)
    }
    
    private func makeItem(id: UUID, description: String? = nil, location: String? = nil, imageURL: URL) -> (model: FeedImage, json: [String: Any]) {
        let item = FeedImage(id: id,
                            description: description,
                            location: location,
                            url: imageURL)
        
        let json = [
            "id": item.id.uuidString,
            "description": item.description,
            "location": item.location,
            "image": item.url.absoluteString
            ].compactMapValues { $0 }
        
        return (item, json)
    }
    
    private func makeItemJSON(_ items: [[String: Any]]) -> Data {
        let json = ["items": items]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    private func expect(sut: RemoteFeedLoader, toCompleteWith expectedResult: RemoteFeedLoader.Result, file: StaticString = #file, line: UInt = #line, when action: () -> Void) {
        let exp = expectation(description: "Wait for load completion")
        
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedItems), .success(expectedItems)):
                XCTAssertEqual(receivedItems, expectedItems, file: file, line: line)
                
            case let (.failure(receivedError as RemoteFeedLoader.Error), .failure(expectedError as RemoteFeedLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
                
            default:
                XCTFail("Expected result \(expectedResult) got \(receivedResult) instead")
            }
            
            exp.fulfill()
        }
            
        action()
        
        wait(for: [exp], timeout: 1.0)
    }
    
}

private extension HTTPURLResponse {
    convenience init(statusCode: Int) {
        self.init(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }
}
