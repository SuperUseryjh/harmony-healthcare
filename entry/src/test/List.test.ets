import localUnitTest from './LocalUnit.test';
import energyCalculatorTest from './EnergyCalculator.test';
import nutritionAnalyzerTest from './NutritionAnalyzer.test';
import healthScoreCalculatorTest from './HealthScoreCalculator.test';
import adviceEngineTest from './AdviceEngine.test';
import petEngineTest from './PetEngine.test';

/**
 * 本地单元测试套件入口。
 *
 * 这里注册的都是纯函数测试（engine 层），不依赖设备、不依赖数据库，
 * 可以在 DevEco Studio 中直接以 Local Test 方式运行。
 */
export default function testsuite() {
  localUnitTest();
  energyCalculatorTest();
  nutritionAnalyzerTest();
  healthScoreCalculatorTest();
  adviceEngineTest();
  petEngineTest();
}
