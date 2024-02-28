//
//  PerfermanceMeasurer.swift
//  ObjectDetection-iOS
//
//  Created by sangju.lee on 2/28/24.
//

import UIKit

// 성능 측정을 위한 델리게이트 프로토콜
protocol PerformanceMeasurerDelegate: AnyObject {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int)
}

// 성능 측정 클래스
class PerfermanceMeasurer: NSObject {
    
    // 델리게이트
    weak var delegate: PerformanceMeasurerDelegate?
    
    // 인덱스 및 측정값 배열 초기화
    private var index: Int = -1
    private var measurements: [Dictionary<String, Double>]
    
    // 초기화 메서드
    override init() {
        let initialMeasurement = ["start": CACurrentMediaTime(), "end": CACurrentMediaTime()]
        measurements = Array<Dictionary<String, Double>>(repeating: initialMeasurement, count: 30)
    }
    
    // 성능 측정 시작
    func startMeasurement() {
        index += 1
        index %= 30
        measurements[index] = [:]
        
        labelMeasurement(with: "start")
    }
    
    // 성능 측정 종료
    func endMeasurement() {
        labelMeasurement(with: "end")
        
        let beforeMeasurement = getBeforeMeasurement(for: index)
        let currentMeasurement = measurements[index]
        
        if let startTime = currentMeasurement["start"],
           let endInferenceTime = currentMeasurement["endInference"],
           let endTime = currentMeasurement["end"],
           let beforeStartTime = beforeMeasurement["start"] {
            delegate?.updateMeasure(inferenceTime: endInferenceTime - startTime,
                                    executionTime: endTime - startTime,
                                    fps: Int(1 / (startTime - beforeStartTime)))
        }
    }
    
    // labeling with
    func labelMeasurement(with msg: String? = "") {
        labelMeasurement(for: index, with: msg)
    }
    
    // 측정값 레이블링
    private func labelMeasurement(for index: Int, with msg: String? = "") {
        if let message = msg {
            measurements[index][message] = CACurrentMediaTime()
        }
    }
    
    // 이전 측정값 가져오기
    private func getBeforeMeasurement(for index: Int) -> Dictionary<String, Double> {
        return measurements[(index + 30 - 1) % 30]
    }
    
    // 로그
    func printLog() {
        // 로그 출력 로직 추가
    }
}

// 성능 측정 로그 뷰
class PerformanceMeasurerLogView: UIView {
    let executionTimeLabel = UILabel(frame: .zero)
    let fpsLabel = UILabel(frame: .zero)
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
